# Project Memory

## Docs Policy

- `docs/` 根目录只保留索引文件 `docs/README.md`，不再放活动文档。
- 活动文档只能进入 `docs/specs/`、`docs/runbooks/`、`docs/guides/`、`docs/adr/`。
- 历史材料只能进入 `docs/archive/`。
- 一个主题只保留一个活动真相源；被新文档吸收的旧文档应删除，只有确有追溯价值时才归档。

## Docs Index Policy

- `docs/README.md` 是文档总索引，必须列出当前收录的文档及其作用。
- `docs/README.md` 中每个条目都必须带 `最后更新：YYYY-MM-DD`。
- 以后每次修改已收录文档，都必须同步更新 `docs/README.md` 对应条目的日期。
- 如果新增、移动、删除文档，必须同时更新 `docs/README.md` 的目录结构和条目说明。

## Practical Rule

- 做文档改动时，默认先检查 `docs/README.md` 是否也需要同步更新。
