import asyncio

from nvchecker.api import AsyncCache, BaseWorker, RawResult


class Worker(BaseWorker):
    async def run(self) -> None:
        self.cache = AsyncCache()
        await asyncio.gather(
            *[self._run_entry(name, entry) for (name, entry) in self.tasks]
        )

    async def _run_entry(self, name, entry):
        async with self.task_sem:
            data = await self.cache.get_json(entry["url"])
            for branch, data in data.items():
                versions = [
                    f"{r['release_date']}-{r['release_version']}"
                    for r in data["driver_info"]
                ]
                await self.result_q.put(
                    RawResult(
                        f"{name}.r{branch}",
                        versions,
                        entry,
                    )
                )
