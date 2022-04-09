#! /usr/bin/env nix-shell
#! nix-shell -i python3 -p python3

import collections
from io import StringIO
import sys
import os
from itertools import islice
from typing import Callable, Iterable, Iterator, List, Optional, Tuple
from pathlib import PurePosixPath


def make_relative(path: PurePosixPath) -> PurePosixPath:
    if path.is_absolute():
        return path.relative_to(path.root)
    else:
        return path


def format_output(src_path: PurePosixPath,
                  target_path: PurePosixPath,
                  permissions: str,
                  file_type: str,
                  module: Optional[str],
                  arch: Optional[str],
                  extra: Optional[str]
                  ) -> str:
    return f'manifest_entry "{make_relative(src_path)}" "{make_relative(target_path)}" ' + \
        f'"{permissions}" "{file_type}" "{module or ""}" "{arch or ""}" "{extra or ""}"'


def filter_path_root(path: str) -> PurePosixPath:
    # pathlib interprets '/' as root, filter that case
    if path == "/":
        return PurePosixPath(".")
    else:
        return PurePosixPath(path)


def resolve_symlink(src_path: PurePosixPath, data: List[str]) -> Tuple[PurePosixPath, PurePosixPath]:
    symlink_target = PurePosixPath(data.pop())
    if len(data):
        target_dir = symlink_target
        symlink_target = PurePosixPath(data.pop())
    else:
        target_dir = PurePosixPath(".")
    return [target_dir / symlink_target, target_dir / src_path]


def maybe_pop(list: List[str], test: Callable[[str], Optional[str]]) -> Optional[str]:
    if len(list):
        result = test(list[-1])
        if result is not None:
            list.pop()
            return result
    return None


def match_enum(*values: str) -> Callable[[str], Optional[str]]:
    """checks if the input is one of the given values, returning the value if true"""
    def matcher(token: str):
        if token in values:
            return token
    return matcher


def match_tag(tag: str) -> Callable[[str], Optional[str]]:
    """checks if the input has the form "{tag}:{str}", returns {str} if it matches"""
    def matcher(token: str):
        parts = token.split(":", 2)
        if parts[0] == tag and len(parts) == 2:
            return parts[1]
    return matcher

def pop_these_dirs(path: PurePosixPath, dirs: List[str]) -> Tuple[PurePosixPath, Optional[str]]:
    segments = path.parts
    if segments[0] in dirs:
        return (PurePosixPath(*segments[1:]), segments[0])
    else:
        return (path, None)

def convert_manifest_entry(raw_line: str, legacy_kernel_depth: int = 1) -> str:
    parts: List[str] = raw_line.strip().split()
    # module was added later, but seems to always be the last token
    module = maybe_pop(parts, match_tag("MODULE"))
    parts.reverse()
    src_file = PurePosixPath(parts.pop())
    perms = parts.pop()
    type = parts.pop()
    arch = maybe_pop(parts, match_enum("NATIVE", "COMPAT32"))
    inherits_path = maybe_pop(parts, match_tag("INHERIT_PATH_DEPTH"))
    target_file = src_file
    extra = None

    if arch == "COMPAT32":
        target_file = PurePosixPath(*target_file.parts[1:])

    # In build 340.108 for x86, TLS_LIB has an extra tag
    #  in build 71.86.15, there TLS_SYMLINK
    if type in ["TLS_LIB", "TLS_SYMLINK"]:
        extra = maybe_pop(parts, match_enum("NEW", "CLASSIC"))

    # In build 1.0.6106, it uses types rather than extra data for TLS/COMPAT32
    #   since it does not consistently mark files for COMPAT32, just discard the data
    type = type.removesuffix("_32")

    # OPENGL_SYMLINK_NEW_TLS[_32] -> TLS_SYMLINK
    if type.endswith("_TLS"):
        type_segments = type.split("_")
        extra = type_segments[-2]
        type_segments[0] = "TLS"
        type = "_".join(type_segments[:-2])

    # In build 390.144 for x86, there are 2 packaged OpenGL versions
    if type.startswith("GLX_CLIENT_") or type.startswith("EGL_CLIENT_"):
        # the tag is after the symlink data, so reverse the parameters temporarily
        parts.reverse()
        extra = maybe_pop(parts, match_enum("GLVND", "NON_GLVND"))
        parts.reverse()

    if type.endswith("_SYMLINK") or type.endswith("_NEWSYM"):
        # symlinks are emitted as $target_file -> $src_file
        # NEWSYM => symbolic link only if doesnt already exist
        (src_file, target_file) = resolve_symlink(src_file, parts)
    elif inherits_path is not None:
        # target path is a copy of source path with the given
        #  number of path segments removed
        target_file = PurePosixPath(*target_file.parts[int(inherits_path):])
    elif type.endswith("_MODULE_SRC") or type.endswith("_MODULE_CMD"):
        # modern kernel sources are handled by INHERIT_PATH_DEPTH,
        #  this ensures the kernel directory gets unpacked
        target_file = PurePosixPath(*target_file.parts[legacy_kernel_depth:])
    elif len(parts):
        # leftover types appear to specify a path to put the source file into
        target_file = PurePosixPath(parts.pop()) / \
            PurePosixPath(target_file.name)
    else:
        # no information about target path, presumably entirely dependent on
        #  the file type
        target_file = PurePosixPath(target_file.name)

    if type == "SYSTEMD_UNIT_SYMLINK":
        # systemd symlinks are used to establish requirements
        #  and the manifest just lists the .requires directory
        #  in opposite order to the other symlinks
        (src_file, target_file) = (target_file, src_file / target_file)

    # Older builds might include lib/lib64 directories in target path
    if arch is None:
        (target_file, popped) = pop_these_dirs(target_file, ["lib", "lib64"])

        # only needed if target location was popped, because of symlinks
        if popped:
            (src_file, _) = pop_these_dirs(src_file, [popped])
        
        if "lib64" == popped:
            arch = "NATIVE"
        elif "lib" == popped:
            arch = "COMPAT32"

    # If consumed data is wrong, the output will be wrong, but ignored
    #  data is not immediately obvious
    if len(parts):
        print(f"Unhandled data: {parts}\n{raw_line}", file=sys.stderr)
        exit(1)

    return format_output(src_file, target_file, perms, type, module, arch, extra)


# from itertools recipes
def consume(iterator, n=None):
    "Advance the iterator n-steps ahead. If n is None, consume entirely."
    # Use functions that consume iterators at C speed.
    if n is None:
        # feed the entire iterator into a zero-length deque
        collections.deque(iterator, maxlen=0)
    else:
        # advance to the empty slice starting at position n
        next(islice(iterator, n, n), None)


def read_header(it: Iterator[str]) -> PurePosixPath:
    # skip 3 lines
    consume(it, 3)
    if next(it).rstrip().endswith(".o"):
        # legacy installer puts modules in line 5
        consume(it, 1)

    consume(it, 2)
    
    kernel_path=PurePosixPath(next(it).rstrip())

    # skip precompiled headers location
    consume(it, 1)

    return kernel_path


def convert_manifest(source: Iterable[str], sink: StringIO):
    it = iter(source)

    # read kernel path from the header
    kernel_dir_depth = len(read_header(it).parts)

    for line in it:
        try:
            print(convert_manifest_entry(line, legacy_kernel_depth=kernel_dir_depth), file=sink)
        except IndexError:
            print("Unexpected manifest entry: ", line, file=sys.stderr)


def main():
    filepath = sys.argv[1]
    if not os.path.isfile(filepath):
        print("File path {} does not exist. Exiting...".format(filepath), file=sys.stderr)
        sys.exit(1)

    with open(filepath) as fp:
        convert_manifest(fp, sys.stdout)


main()
