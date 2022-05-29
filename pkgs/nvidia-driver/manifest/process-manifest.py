import argparse
import json
import pprint
from collections import deque
from dataclasses import asdict, dataclass, field
from fnmatch import fnmatch
from functools import cached_property, partial
from itertools import groupby, starmap
from operator import attrgetter
from pathlib import Path, PurePosixPath
from typing import Any, Callable, Generic, Iterable, Iterator, Optional, TypeVar

from more_itertools import consume, partition, side_effect

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

    # set during installation process
    categories: list[str] = field(default_factory=list)
    overrides: dict[str, str] = field(default_factory=dict)

    @cached_property
    def target_path(self) -> PurePosixPath:
        return self.entry.path / self.entry.file_path.name

    @cached_property
    def src_path(self) -> PurePosixPath:
        if self.entry.ln_target is not None:
            return self.entry.path / self.entry.ln_target
        else:
            return self.entry.file_path

    @property
    def extra(self) -> Optional[str]:
        return self.entry.glvnd_variant or self.entry.tls_class

    @property
    def category(self) -> Optional[str]:
        return next(iter(self.categories), None)

    @property
    def install_directory(self) -> PurePosixPath:
        install_dir = to_relative_path(PurePosixPath(self.overrides.get("dir", "/lib")))
        install_prefix = self.overrides.get("prefix", "!outputLib")
        return PurePosixPath(f"${{{install_prefix}}}") / install_dir

    @cached_property
    def install_path(self) -> PurePosixPath:
        return self.install_directory / self.target_path

    @cached_property
    def link_path(self) -> PurePosixPath:
        return (
            PurePosixPath(self.overrides.get("ln_override", self.install_directory))
            / self.src_path
        )

    def __getattr__(self, name):
        return getattr(self.entry, name)


def read_manifest(path: Path) -> Iterable[InstallableEntry]:
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
                # modprobe binary
                "usr/bin/",
                # ancient builds embed FHS into manifest paths
                "share/doc/NVIDIA_GLX-1.0/",
                "lib64/",
                "lib/",
                # added to all documentation-like items
                "NVIDIA_GLX-1.0/",
            ],
        )

        entry.path = new_path

        # if we need to remove lib64/ or lib/, the
        #   architecture isn't specified
        if popped and entry.architecture is None:
            entry.architecture = {"lib64/": "NATIVE", "lib/": "COMPAT32"}.get(
                popped, None
            )

    with path.open() as f:
        source = map(str.rstrip, f)
        header = ManifestHeader.parse_header(source)

        for raw_entry in source:
            try:
                entry = ManifestEntry.parse_entry(raw_entry)
                # patch some inconsistencies in manifest data...
                patch_entry(entry, header.kernel_module_build_dir)
                yield InstallableEntry(raw_entry, entry)
            except Exception as ex:
                raise ValueError(f"unexpected entry: {raw_entry}") from ex


class ManifestEnhancer:
    def __init__(
        self,
        categories: dict[str, tuple[Callable[[T], bool], list[str]]],
        overrides: list[tuple[Callable[[T], bool], dict[str, str]]],
    ) -> None:
        self._categories = categories
        self._overrides = overrides

    def _match_categories(self, entry: InstallableEntry) -> Iterable[str]:
        for (category, (match, _)) in self._categories.items():
            if match(entry):
                yield category

    def _get_overrides(self, entry: InstallableEntry) -> dict[str, str]:
        data = {}
        for (match, extra) in self._overrides:
            if match(entry):
                data.update(extra)
        return data

    def enhance_entry(self, entry: InstallableEntry) -> None:
        entry.categories = list(self._match_categories(entry))
        entry.overrides = self._get_overrides(entry)

    def category_dependencies(self) -> Iterable[tuple[str, list[str]]]:
        for (category, (_, deps)) in self._categories.items():
            yield category, deps

    @staticmethod
    def json_load(path: Path) -> Any:
        def match_variable(
            entry: T, variable: str, patterns: Iterable[str]
        ) -> Iterable[bool]:
            value = getattr(entry, variable)
            if isinstance(value, PurePosixPath):
                yield from map(value.match, patterns)
            elif isinstance(value, str):
                yield from map(partial(fnmatch, value), patterns)
            elif value is None:
                yield False
            else:
                raise ValueError(f"Unhandled variable type: {value}")

        def apply_in_order(input: Any):
            if isinstance(input, dict):
                fns = input.values()
            elif isinstance(input, list):
                fns = input
            else:
                raise ValueError(f"unknown value type: {input}")

            def apply(entry: T) -> Iterable[bool]:
                for fn in fns:
                    yield fn(entry)

            return apply

        def json_hook(data_raw: list[tuple]) -> Any:
            data = dict(data_raw)
            if len(data_raw) != 2 or data.keys() != {"op", "args"}:
                return data

            op = data["op"]
            args = data["args"]

            if op == "match":
                variable = args["variable"]
                patterns = args["pattern"]
                if not isinstance(patterns, list):
                    patterns = [patterns]

                def doMatch(value: T) -> bool:
                    return any(match_variable(value, variable, patterns))

                return doMatch
            elif op == "not":
                fn = args

                def doNot(entry: T) -> bool:
                    return bool(not fn(entry))

                return doNot
            elif op == "all":
                fn = apply_in_order(args)

                def doAll(entry: T) -> bool:
                    return all(fn(entry))

                return doAll
            elif op == "any":
                fn = apply_in_order(args)

                def doAny(entry: T) -> bool:
                    return any(fn(entry))

                return doAny
            else:
                raise ValueError(f"unknown operator: {data}")

        with path.open() as f:
            return json.load(f, object_pairs_hook=json_hook)

    @classmethod
    def load_from(
        cls, matchers_json_path: Optional[Path], locations_json_path: Optional[Path]
    ) -> "ManifestEnhancer":
        def load_with_default(path: Optional[Path], default: T) -> T:
            if path is not None:
                return cls.json_load(path)
            else:
                return default

        matcher_json = load_with_default(matchers_json_path, {})
        locations_json = load_with_default(locations_json_path, [])

        def default_matcher(_):
            return False

        def flatten_data(path: list[str], data: Any):
            submatchers = list()
            matcher = default_matcher
            if callable(data):
                matcher = data
            elif isinstance(data, dict):
                for (k, v) in data.items():
                    submatcher = yield from flatten_data(path + [k], v)
                    submatchers.append(submatcher)

            if len(path):
                name = ".".join(path)
            else:
                name = "_all"

            yield name, (matcher, submatchers)

            return name

        def rule_to_tuple(data):
            data = data.copy()
            check = data.pop("check")
            return check, data

        return cls(
            categories=dict(flatten_data([], matcher_json)),
            overrides=list(map(rule_to_tuple, locations_json)),
        )


class InstallScriptGenerator:
    def __init__(self, out_path: Path) -> None:
        self._out_path = out_path
        self._scripts = dict[Path, list[str]]()

    def _resolve_name(self, category: str, suffix: Optional[str] = None) -> Path:
        file_suffix = f"-{suffix}" if suffix is not None else ""
        return self._out_path / "c" / category / f"install{file_suffix}.sh"

    def _get_script_output(self, file: Path) -> list[str]:
        return self._scripts.setdefault(file, [])

    def add_dependencies(self, category: str, dependencies: list[str]) -> None:
        out = self._get_script_output(self._resolve_name(category))

        for dep in dependencies:
            out.append(f"echo \"installing '{dep}'\"")
            out.append(f"source {self._resolve_name(dep)}")

    def consume_entries(self, entries: Iterable[InstallableEntry]) -> None:
        def is_compat32(entry: InstallableEntry):
            return entry.entry.architecture == "COMPAT32"

        def install_dir(entry: InstallableEntry):
            return entry.install_path.parent

        def generate_shellcode(entries: Iterable[InstallableEntry]):
            for (dir, entries) in groupby(entries, key=install_dir):
                yield f"mkdir -p {dir}"
                for entry in entries:
                    yield f"# {entry.raw_entry}"
                    if entry.entry.ln_target is not None:
                        yield "ln -s -r \\"
                        yield '  -b -S "~collision" \\'
                        yield f"  -T {entry.link_path} \\"
                    else:
                        # cut mode to last 3 characters to avoid setting
                        # special permissions
                        yield f"install -D -m {entry.entry.mode[-3:]} \\"
                        yield f"  -T {entry.src_path} \\"
                    yield f"  {entry.install_path}"

        entries = list(entries)
        entries.sort(key=attrgetter("install_path"))
        entries.sort(key=attrgetter("category"))
        for (category, entries) in groupby(entries, key=attrgetter("category")):
            out = self._get_script_output(self._resolve_name(category))
            (native, compat32) = partition(is_compat32, entries)
            out.extend(generate_shellcode(native))

            compat32 = list(compat32)
            if len(compat32):
                compat_file = self._resolve_name(category, suffix="compat32")
                # write out compat32 to seperate file
                self._get_script_output(compat_file).extend(
                    generate_shellcode(compat32)
                )
                # source with an override for outputLib
                out.append(f"outputLib=lib32 source {compat_file}")

    def write_files(self) -> None:
        for (file, source) in self._scripts.items():
            if not len(source):
                category = file.parent.name
                source = [f'echo "{category}: no files to install"']

            file.parent.mkdir(parents=True, exist_ok=True)
            with file.open("w") as f:
                print(*source, sep="\n", file=f)


def process_manifest(
    manifestPath: Path,
    locationsPath: Path,
    matchersPath: Path,
    outPath: Path,
) -> None:
    enhancer = ManifestEnhancer.load_from(matchersPath, locationsPath)
    scripts = InstallScriptGenerator(outPath)
    consume(starmap(scripts.add_dependencies, enhancer.category_dependencies()))

    # split entries on whether they matched to a single category
    (entries, mismatched_entries) = partition(
        lambda e: len(e.categories) != 1,
        side_effect(enhancer.enhance_entry, read_manifest(manifestPath)),
    )

    # generate install scripts
    scripts.consume_entries(entries)

    # before generating files, ensure the output directory exists
    outPath.mkdir(parents=True, exist_ok=True)

    scripts.write_files()

    # write out problematic matches to file
    mismatched_entries = list(map(asdict, mismatched_entries))
    if len(mismatched_entries):
        print(f"{len(mismatched_entries)} manifest entries mismatched")
        with outPath.joinpath("mismatched.txt").open("w") as f:
            pprint.pprint(mismatched_entries, stream=f)

    with outPath.joinpath("install.sh").open("w") as f:
        print(
            '# usage: $manifest/install.sh $source "matcher-name"',
            f"cd $1 && source {outPath}/c/$2/install.sh",
            sep="\n",
            file=f,
        )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--matchers", type=Path, required=True)
    parser.add_argument("--locations", type=Path, required=True)
    parser.add_argument("--outpath", type=Path, required=True)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()

    process_manifest(args.manifest, args.locations, args.matchers, args.outpath)


if __name__ == "__main__":
    main()
