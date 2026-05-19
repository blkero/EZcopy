# Phase 2 Photo Selection

Phase 2 adds the first real iPhone media selection flow.

## Included

- System Photos picker for selecting iPhone photos and videos.
- Multiple selection with image and video filtering.
- Selected media summary counts.
- Selected media list UI.
- PhotoKit lookup from picker asset identifiers.
- Original resource filename discovery where PhotoKit exposes it.
- Basic metadata display:
  - Media type.
  - Creation date.
  - Pixel dimensions.
  - Video duration.

## Notes

- File size is not shown yet because the MVP should avoid loading large videos into memory just to estimate transfer size.
- Source MD5 calculation is deferred to the export/transfer phase, where files can be streamed safely.
- The next phase should turn selected assets into a transfer session manifest and prepare original-resource export.
