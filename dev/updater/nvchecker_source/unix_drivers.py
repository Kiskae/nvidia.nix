import re

from nvchecker.api import BaseWorker, RawResult, session

PATTERN = re.compile(rb"Latest (?P<label>[^:]+)[^>]+>\s*(?P<version>[^<]+)</a>")


class Worker(BaseWorker):
    async def get_data(self, url):
        for match in PATTERN.finditer(res.body):
            yield match.groupdict()

    async def get_unix_results(self, url):
        results = {}
        res = await session.get(url)

        for match in PATTERN.finditer(res.body):
            label = match["label"].lower()
            versions = results.get(label) or set()
            versions.add(match["version"].decode("UTF-8"))
            if label not in results:
                results[label] = versions

        return results

    def match_label(self, label: str, known_entries):
        for known in known_entries:
            if known["match"].lower() in label:
                return (
                    known.get("branch", "current"),
                    known.get("maturity", "official"),
                )

        return (None, None)

    async def run(self) -> None:
        results = None
        async with self.task_sem:
            results = await self.get_unix_results(
                "https://www.nvidia.com/en-us/drivers/unix/"
            )

        for name, entry in self.tasks:
            known_entries = entry.get("known")

            async with self.task_sem:
                for label, versions in results.items():
                    label_str = label.decode("UTF-8")
                    (branch, maturity) = self.match_label(label_str, known_entries)

                    new_name = f"{name}.unknown.{label_str}"
                    if branch:
                        new_name = f"{name}.{branch}.{maturity}"

                    await self.result_q.put(
                        RawResult(
                            new_name,
                            list(versions),
                            entry,
                        )
                    )
