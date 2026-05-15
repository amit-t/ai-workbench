# Changelog

All notable changes to ai-workbench (template) are documented here. release-please appends entries on every merge to `main` based on Conventional Commit messages.

## [1.4.0](https://github.com/amit-t/ai-workbench/compare/v1.3.0...v1.4.0) (2026-05-15)


### Features

* **skills:** install precision-mode skill ([bbacea5](https://github.com/amit-t/ai-workbench/commit/bbacea593eeef73ea44d1e5e35cde6111acccd1b))
* **skills:** wire precision-mode into 9 draft hosts (Phase 3) ([5e0ca31](https://github.com/amit-t/ai-workbench/commit/5e0ca318ea3c90b4e0635f11cffdd3bf5be9c340))
* **skills:** wire precision-mode into 9 draft hosts (Phase 3) ([57e51af](https://github.com/amit-t/ai-workbench/commit/57e51afafa3f27a31c0b42c2b1e4430879b27d47))

## [1.3.0](https://github.com/amit-t/ai-workbench/compare/v1.2.1...v1.3.0) (2026-05-15)


### Features

* **skills:** add shared grill workflows for specs and plans ([dc1ed77](https://github.com/amit-t/ai-workbench/commit/dc1ed7791243517b71a56864e7da4a35473668d0))
* **skills:** package domain grilling workflows ([28b8b4e](https://github.com/amit-t/ai-workbench/commit/28b8b4e9c8fe3774259196e29e05dd3441bcef2d))
* **skills:** wire implicit grill into 9 draft skills ([54fad78](https://github.com/amit-t/ai-workbench/commit/54fad789e01d852543659811618d0584b34b8392))
* **skills:** wire implicit grill step into 9 draft-producing skills ([34e880d](https://github.com/amit-t/ai-workbench/commit/34e880d956ef998f83b324f7cd66c8b59dc5366f))

## [1.2.1](https://github.com/amit-t/ai-workbench/compare/v1.2.0...v1.2.1) (2026-05-14)


### Bug Fixes

* **scan:** wb.rescan brick — permission-mode, flag order, stdout leak ([#35](https://github.com/amit-t/ai-workbench/issues/35)) ([66fc7ee](https://github.com/amit-t/ai-workbench/commit/66fc7ee1054139ef0c3ac2070c35054bc10c5f61))

## [1.2.0](https://github.com/amit-t/ai-workbench/compare/v1.1.0...v1.2.0) (2026-05-14)


### Features

* **scan:** sync dev → main (wb.rescan + context scan auto-run) ([3fc698e](https://github.com/amit-t/ai-workbench/commit/3fc698e91cc1d9a5273502f66b876ee6cbaed70d))

## [1.1.0](https://github.com/amit-t/ai-workbench/compare/v1.0.0...v1.1.0) (2026-05-13)


### Features

* **aliases:** add _wb_check preamble to meaningful wb.* commands ([a4ed799](https://github.com/amit-t/ai-workbench/commit/a4ed79962ad54cda2ecef215fe8cbceb13ee2939))
* **aliases:** resolve target wb per call (multi-workbench support) ([2b1c349](https://github.com/amit-t/ai-workbench/commit/2b1c3497fbe69bc3187db3ff67f07db151fbedf2))
* **aliases:** resolve target wb per call so one source serves many workbenches ([f48de95](https://github.com/amit-t/ai-workbench/commit/f48de954a5a134115db785d6b6a87b33dd4305c5))
* **ci:** wb-side CI lint workflow seeded by update.wb ([77e4d9a](https://github.com/amit-t/ai-workbench/commit/77e4d9adb9b006358bda5c942edde35bf76d4ba6))
* **ci:** wb-side CI lint workflow seeded by update.wb (D2) ([e5b6998](https://github.com/amit-t/ai-workbench/commit/e5b6998c4b27d69780aa72046f01d5d8b908d24b))
* **devkit,ralph:** bootstrap ralph workspace mode in init.wb / join.wb ([239936b](https://github.com/amit-t/ai-workbench/commit/239936b8f7a34cc9865a582cedce5c35bd32828b))
* initial workbench template ([7dfbc79](https://github.com/amit-t/ai-workbench/commit/7dfbc7979ae194f91e622052415f57b4efbec0be))
* **lifecycle:** unified lifecycle.py CLI with BDD support and flock ([d7ead44](https://github.com/amit-t/ai-workbench/commit/d7ead4456e285b565dc27a7145bda5a2ff91dbea))
* ralph self-host + stamped-wb ralph bootstrap (Plan F) ([a6a41d0](https://github.com/amit-t/ai-workbench/commit/a6a41d0056f8d58efba08c7be26dcf3cc3418495))
* ralph self-host + stamped-wb ralph bootstrap (Plan F) ([9e007cc](https://github.com/amit-t/ai-workbench/commit/9e007ccba5e4ed7c9a68c8e8a2b2f19eced8feb0))
* **ralph-adapter:** workspace-mode wrappers + target_repos routing + M4 drift footer ([5ae20f6](https://github.com/amit-t/ai-workbench/commit/5ae20f6a2783d48659ec6b93c5045d74a90ed0bb))
* **ralph-adapter:** workspace-mode wrappers + target_repos routing + M4 drift footer ([5136f0d](https://github.com/amit-t/ai-workbench/commit/5136f0dd5a51048692e50b410ef1706625e60ec4))
* **ralph-adapter:** workspace-mode wrappers, target_repos routing, M4 drift footer ([0bdd87d](https://github.com/amit-t/ai-workbench/commit/0bdd87db37145538b4ea0ac329f6896c584971f5))
* **ralph:** add wb.ralph-plan --replan &lt;repo&gt; for single-repo replan ([fa8dafb](https://github.com/amit-t/ai-workbench/commit/fa8dafb392e9ed31b8a44e673a237cb97180c857))
* **skills:** add a reusable handoff skill ([e1725a4](https://github.com/amit-t/ai-workbench/commit/e1725a45ce8a2dc8323dd7d910fb3ae8105ca1e2))
* **skills:** add docs-from-prs skill to keep docs in sync ([f5f32e2](https://github.com/amit-t/ai-workbench/commit/f5f32e2007461b99afacf7224fbe8c2382f02a0a))
* **skills:** add neo-brutalist github pages scaffolder ([e1fa706](https://github.com/amit-t/ai-workbench/commit/e1fa7069df4db77732e6461d4436913e00c5a23c))
* **skills:** fill 9 remaining skill bodies; add wb.rejected lister ([178434a](https://github.com/amit-t/ai-workbench/commit/178434a8a01807c5d3b40be8768eea8191d9ebaf))
* **steering:** mtime-keyed cache for steering-load.py ([4c9a273](https://github.com/amit-t/ai-workbench/commit/4c9a2734aff8d239c90ae920a7ec41a10e0ea178))
* **steering:** mtime-keyed cache for steering-load.py (Plan D4) ([eb8e1a7](https://github.com/amit-t/ai-workbench/commit/eb8e1a7b3aac6fef23b6d7b3df8b3a341d925212))
* **steering:** team steering system with progressive disclosure and overlays ([ca4f9dc](https://github.com/amit-t/ai-workbench/commit/ca4f9dc6c7b30811efcf533834da611eeb32c988))
* **steering:** team steering system with progressive disclosure and overlays ([8a9278c](https://github.com/amit-t/ai-workbench/commit/8a9278c2aeb218f570ebe26a9fce8c0912cb0140))
* **steering:** team steering system with progressive disclosure and overlays ([00ac061](https://github.com/amit-t/ai-workbench/commit/00ac061af22574fa25a428d1c2589647832c1d05))
* **steering:** wb.steering-audit surfaces overlay drift + promote-suggest heuristic ([cc2d9b9](https://github.com/amit-t/ai-workbench/commit/cc2d9b98b499bb689a08e08a9b982bcde3323698))
* **steering:** wb.steering-audit surfaces overlay drift + promote-suggest heuristic ([bbd3f68](https://github.com/amit-t/ai-workbench/commit/bbd3f68e80a36b342e3125134642928436743db1))
* versioning template-side wiring (version.json + aliases preamble + minimal agent notes) ([2e0471e](https://github.com/amit-t/ai-workbench/commit/2e0471e65b55595c0641551af3753868f5172143))
* versioning template-side wiring (version.json + aliases preamble + minimal agent notes) ([321f124](https://github.com/amit-t/ai-workbench/commit/321f12412eb5499c2bd0311cca0b05a0d74dae0f))
* **version:** seed version.json at 1.0.0 and CHANGELOG ([9685161](https://github.com/amit-t/ai-workbench/commit/96851618694c23887ee4fd6192a36c819f0c174e))
* **wrappers:** wire ralph V2 --repos/--exclude/--parallel-plan passthrough ([6e00d2b](https://github.com/amit-t/ai-workbench/commit/6e00d2b98e321b0049904131b2b4baa927a9f417))
* **wrappers:** wire ralph V2 --repos/--exclude/--parallel-plan passthrough ([c80cec1](https://github.com/amit-t/ai-workbench/commit/c80cec1287310a6581d8f9769a6d942e0d3b23a3))
* **wrappers:** wire ralph V2 --repos/--exclude/--parallel-plan passthrough ([1a8cbb7](https://github.com/amit-t/ai-workbench/commit/1a8cbb737e94f652f0cf8ddc5aac0611b8a6cea8))
* **wrappers:** wire ralph V2 --repos/--exclude/--parallel-plan passthrough ([8f01267](https://github.com/amit-t/ai-workbench/commit/8f0126758bb38f14343b8cb36317c305dbad13a7))


### Bug Fixes

* **aliases:** drop 2&gt;&1 from _wb_check so version-check stays on stderr ([e0043fe](https://github.com/amit-t/ai-workbench/commit/e0043fe45f1131ec8a4edb95d4c5a4b10ca85b14))
* **claude:** correct $schema URL in settings.json ([1b643ab](https://github.com/amit-t/ai-workbench/commit/1b643ab9c9930aef27adde1fdc1362db39fd915c))

## 1.0.0 (2026-05-09)

* feat: introduce versioning system + `wb.upgrade` notification on every wb.* command (initial release).
