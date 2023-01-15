import argparse
import json
import sys
from collections import deque
from dataclasses import asdict, dataclass
from pathlib import PurePosixPath
from typing import Any, Callable, Generic, Iterable, Iterator, Optional, TextIO, TypeVar

T = TypeVar("T")
R = TypeVar("R")


class FlippableDeque(Generic[T]):
    _handlers: list[tuple[int, Callable[[deque[T]], T]]] = [
        (0, deque[T].popleft),
        (-1, deque[T].pop),
    ]

    def __init__(self, it: Iterable[T]) -> None:
        self._data = deque(it)
        self._flipped = False

    def __len__(self):
        return len(self._data)

    def __repr__(self) -> str:
        return repr(self._data)

    def _current_handler(self):
        return self._handlers[int(self._flipped)]

    def flip(self) -> None:
        self._flipped = not self._flipped

    def peek(self) -> T:
        (index, _) = self._current_handler()
        return self._data[index]

    def pop(self) -> T:
        (_, pop) = self._current_handler()
        return pop(self._data)

    def pop_if(self, test: Callable[[T], R]) -> Optional[R]:
        result = None

        if len(self):
            result = test(self.peek())

        if result is not None:
            self.pop()

        return result


def to_relative_path(p: PurePosixPath) -> PurePosixPath:
    return p.relative_to(p.root)


@dataclass
class ManifestHeader:
    """nvidia-installer manifest header"""

    # a description string
    description: str
    # a version string
    version: str
    # the kernel module file name
    # NOTE: has been removed from nvidia-installer for quite a while
    kernel_module_file: Optional[PurePosixPath]
    # the kernel interface file name
    kernel_interface_file: Optional[PurePosixPath]
    # the list of kernel modules
    kernel_module_names: list[str]
    # a whitespace-separated list of module names that should be
    #  removed before installing a new kernel module
    module_names_to_uninstall: list[str]
    # a whitespace-separated list of kernel module filenames that
    #  should be uninstalled before installing a new kernel module
    module_files_to_uninstall: list[PurePosixPath]
    # kernel module build directory
    kernel_module_build_dir: PurePosixPath
    # directory containing precompiled kernel interfaces
    precompiled_kernel_dir: PurePosixPath

    @classmethod
    def parse_header(cls, source: Iterator[str]) -> "ManifestHeader":
        def to_path_list(line: str) -> Iterable[PurePosixPath]:
            return map(PurePosixPath, line.split())

        description = next(source)
        version = next(source)
        kernel_module_file = None
        kernel_interface_file = next(to_path_list(next(source)), None)

        # at some point manifests stopped including the module filename,
        #  can be detected by checking the 4th line for an object file extension
        tmp = next(source)
        if tmp.endswith(".o"):
            kernel_module_file = kernel_interface_file
            kernel_interface_file = next(to_path_list(tmp), None)
            tmp = next(source)
        kernel_module_names = tmp.split()

        module_names_to_uninstall = next(source).split()
        module_files_to_uninstall = list(to_path_list(next(source)))
        kernel_module_build_dir = next(to_path_list(next(source)))
        precompiled_kernel_dir = next(to_path_list(next(source)))

        return cls(
            description=description,
            version=version,
            kernel_module_file=kernel_module_file,
            kernel_interface_file=kernel_interface_file,
            kernel_module_names=kernel_module_names,
            module_names_to_uninstall=module_names_to_uninstall,
            module_files_to_uninstall=module_files_to_uninstall,
            kernel_module_build_dir=kernel_module_build_dir,
            precompiled_kernel_dir=precompiled_kernel_dir,
        )


@dataclass
class ManifestEntry:
    file_path: PurePosixPath
    mode: str
    type: str

    path: PurePosixPath
    ln_target: Optional[PurePosixPath]

    architecture: Optional[str]
    tls_class: Optional[str]
    glvnd_variant: Optional[str]
    module: Optional[str]

    @staticmethod
    def match_enum(*values: str) -> Callable[[str], Optional[str]]:
        """checks if the input is one of the given values,
        returning the value if true"""

        def matcher(token: str):
            if token in values:
                return token

        return matcher

    @staticmethod
    def match_tag(tag: str) -> Callable[[str], Optional[str]]:
        """checks if the input has the form "{tag}:{str}",
        returns {str} if it matches"""

        def matcher(token: str):
            parts = token.split(":", 2)
            if parts[0] == tag and len(parts) == 2:
                return parts[1]

        return matcher

    @classmethod
    def parse_entry(cls, raw_entry: str) -> "ManifestEntry":
        q = FlippableDeque(raw_entry.split())

        # a filename (relative to the cwd)
        file_path = PurePosixPath(q.pop())
        # an octal value describing the permissions
        mode = q.pop()
        # a flag describing the file type
        type = q.pop()

        # flags whether it concerns a native or 32-bit executable
        architecture = q.pop_if(cls.match_enum("NATIVE", "COMPAT32"))
        # kernel TLS implementations
        tls_class = q.pop_if(cls.match_enum("CLASSIC", "NEW"))

        # the following items are more consistently parsed back-to-front
        q.flip()
        module = q.pop_if(cls.match_tag("MODULE"))
        # on builds that ship both, ambiguates native and glvnd implementations
        glvnd_variant = q.pop_if(cls.match_enum("GLVND", "NON_GLVND"))

        ln_target = None
        if type == "SYSTEMD_UNIT_SYMLINK":
            # manifest doesnt actually include a symlink target
            #  but since it involves .requires directory links
            #  we can safely link to the parent directory
            # NOTE: actually a bug and memory leak in the nvidia-installer
            ln_target = PurePosixPath("..") / file_path.name
        elif mode == "0000":
            # technically speaking a regular file can have a mode of 0000
            #  but that doesnt make sense for the nvidia installer to do
            ln_target = PurePosixPath(q.pop())

        q.flip()

        inherit_path_depth = q.pop_if(cls.match_tag("INHERIT_PATH_DEPTH"))
        if inherit_path_depth is not None:
            path = PurePosixPath(*file_path.parent.parts[int(inherit_path_depth) :])
        elif len(q):
            # make sure the path is relative
            path = to_relative_path(PurePosixPath(q.pop()))
        else:
            path = PurePosixPath(".")

        assert not len(q), f"unhandled data: {q}"

        return cls(
            file_path=file_path,
            mode=mode,
            type=type,
            architecture=architecture,
            tls_class=tls_class,
            module=module,
            glvnd_variant=glvnd_variant,
            ln_target=ln_target,
            path=path,
        )


@dataclass
class InstallableEntry:
    raw_entry: str
    entry: ManifestEntry


def read_manifest(
    source: TextIO,
) -> tuple[ManifestHeader, Iterable[InstallableEntry]]:
    def remove_known_prefixes(
        path: PurePosixPath, prefixes: list[str]
    ) -> tuple[PurePosixPath, Optional[str]]:
        for prefix in prefixes:
            if path.is_relative_to(prefix):
                return (path.relative_to(prefix), prefix)
        return (path, None)

    def patch_entry(entry: ManifestEntry, legacy_kernel_dir: PurePosixPath) -> None:
        # Patch output directory for kernel sources, keeping the directory structure
        #  pre build-390, where INHERIT_PATH_DEPTH was added for this problem
        if entry.file_path.is_relative_to(legacy_kernel_dir) and not len(
            entry.path.parts
        ):
            entry.path = entry.file_path.relative_to(legacy_kernel_dir).parent

        # ancient legacy builds have non-consistent types:
        # example from 1.0-6106: OPENGL_SYMLINK_NEW_TLS_32
        type = entry.type.removesuffix("_32")
        if type.endswith("_TLS"):
            type_segments = type.split("_")
            type_segments[0] = "TLS"
            # patch type and tls variant
            entry.tls_class = type_segments[-2]
            entry.type = "_".join(type_segments[:-2])

        # some ancient builds dont set the target directory for opengl headers
        if type == "OPENGL_HEADER":
            entry.path = PurePosixPath("GL")

        (new_path, popped) = remove_known_prefixes(
            entry.path,
            [
                # ancient builds embed FHS into manifest paths
                "share/doc/",
                "lib64/",
                "lib/",
            ],
        )

        entry.path = new_path

        # if we need to remove lib64/ or lib/, the
        #   architecture isn't specified
        if popped and entry.architecture is None:
            entry.architecture = {"lib64/": "NATIVE", "lib/": "COMPAT32"}.get(
                popped, None
            )

    source = map(str.rstrip, source)
    header = ManifestHeader.parse_header(source)

    def iter() -> Iterable[InstallableEntry]:
        for raw_entry in source:
            try:
                entry = ManifestEntry.parse_entry(raw_entry)
                # patch some inconsistencies in manifest data...
                patch_entry(entry, header.kernel_module_build_dir)
                yield InstallableEntry(raw_entry, entry)
            except Exception as ex:
                raise ValueError(f"unexpected entry: {raw_entry}") from ex

    return header, iter()


class PathEncoder(json.JSONEncoder):
    def default(self, o: Any) -> Any:
        if isinstance(o, PurePosixPath):
            return o.as_posix()
        return super().default(o)


def process_manifest(
    manifestSource: TextIO, entrySink: TextIO, headerSink: TextIO
) -> None:
    (header, entries) = read_manifest(manifestSource)

    # write out header data
    json.dump(asdict(header), fp=headerSink, cls=PathEncoder)
    headerSink.flush()

    # write manifest entries
    for entry in entries:
        json.dump(asdict(entry), fp=entrySink, cls=PathEncoder)
        entrySink.write("\n")
    entrySink.flush()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--entries", type=argparse.FileType("w"), default=sys.stdout)
    parser.add_argument("--header", type=argparse.FileType("w"), default=sys.stderr)
    parser.add_argument(
        "manifest", nargs="?", type=argparse.FileType("r"), default=sys.stdin
    )
    args = parser.parse_args()

    process_manifest(args.manifest, args.entries, args.header)


if __name__ == "__main__":
    main()
