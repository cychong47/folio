# Photo Clustering Algorithm

## Overview

Photos are grouped into "events" using a **sequential, threshold-based scan** over
time-sorted assets. The same engine is used both for the initial ingestion pass
(which produces the event list) and for the manual "Split Event" panel, but the
manual Both mode uses a stricter split rule so users can separate true place
changes without idle time alone forcing a split.

Source: `folio/Services/ClusteringEngine.swift`

---

## Initial clustering (`cluster`)

Photos and screenshots are handled separately before being merged and sorted by
start date.

**Photos** — clustered by time **and** location (`clusterByTimeAndLocation`).  
**Screenshots** — clustered by time only (`clusterByTimeOnly`); they carry no GPS.

After grouping, each cluster runs through **burst detection** (`detectBursts`),
which marks photos taken within 3 seconds of each other as a stack and picks the
highest-resolution frame as the primary.

---

## Grouping strategies

### Time only (`clusterByTimeOnly`)

```
sort by timestamp
for each consecutive pair (prev, curr):
    if curr.time − prev.time > temporalThreshold  →  new group
    else                                           →  same group
```

Default `temporalThreshold`: **5400 s (90 min)**

### Time + location (`clusterByTimeAndLocation`)

```
sort by timestamp
for each consecutive pair (prev, curr):
    dt = curr.time − prev.time
    dd = haversine(currentGroup.centroid, curr.coord)
    if dt > temporalThreshold
        OR (dd > spatialThreshold AND dt > 60)  →  new group, reset centroid
    else                                         →  same group
                                                   add curr.coord to centroid
```

Default `spatialThreshold`: **500 m**  
The `dt > 60` guard prevents GPS jitter from splitting a stationary burst.
Photos without GPS do not contribute to the centroid and do not trigger spatial
splits; they can still trigger a time-gap split.

### Location only (`clusterByLocationOnly`)

```
sort by timestamp
for each curr:
    dd = haversine(currentGroup.centroid, curr.coord)
    if dd > spatialThreshold  →  new group, reset centroid
    else                      →  same group, add curr.coord to centroid
```

Photos without GPS are ignored by the centroid and therefore never trigger a
location-only split by themselves.

---

## Split Event panel modes

The same three grouping primitives are re-used when the user manually splits a
cluster:

| Mode | Strategy used |
|---|---|
| Time | `clusterByTimeOnly` |
| Location | `clusterByLocationOnly` |
| Both | `clusterByTimeAndLocation` with `timeAndLocation` split rule |

Initial ingestion uses the `timeOrLocation` rule: a long time gap or a meaningful
move can start a new event. Manual Both mode uses the `timeAndLocation` rule: the
candidate split point must have both a long time gap and a meaningful move. This
keeps a long lunch or café stop together when the user is manually refining an
event by place.

`computeGroupAssignments` returns a `[Int]` (one group index per asset in original
order) used for live color-coding in the grid. `applySplit` in `CurationStore`
calls `splitIntoGroups` and replaces the original cluster with the sub-clusters.

---

## Distance formula

Haversine great-circle distance on a sphere of radius 6 371 000 m:

```
φ1, φ2 = latitudes in radians
Δφ = φ2 − φ1,  Δλ = λ2 − λ1
a = sin²(Δφ/2) + cos(φ1)·cos(φ2)·sin²(Δλ/2)
d = 2R · atan2(√a, √(1−a))
```

---

## Known limitations

### 1. Location mode ignores time
Photos taken hours apart at the same coordinate (e.g. returning to a hotel the next
morning) stay in one group because distance alone controls the split.

### 2. GPS-less photos never trigger a spatial split
Missing coordinates are ignored for centroid calculations, so no-GPS photos do not
start a new location group even when they belong to a different place. In time-aware
modes they can still split on a long time gap.

### 3. Centroids are arithmetic means
The running centroid is a simple mean of latitude and longitude. This is accurate
enough for city-scale event grouping but is not a geodesic centroid and can be
imprecise for very large areas or routes crossing the antimeridian.

---

## Possible improvements

- **DBSCAN spatial pass**: after the sequential time split, run a density scan
  within each time window to catch photos that are geographically isolated even
  though they are temporally adjacent.
- **Reverse-geocode place labels**: use city/neighborhood changes as additional
  hints when GPS distance alone is ambiguous.
- **Vision scene classification**: use `VNClassifyImageRequest` to flag content
  changes (indoor → outdoor, food → landscape) as candidate split points within a
  single time cluster.
