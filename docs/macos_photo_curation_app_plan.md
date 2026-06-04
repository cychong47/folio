# Project Plan: Local macOS Photo Curation App for Blog Workflows

## 1. Executive Summary
When returning from multi-day family trips, travelers frequently face the "photo deluge" problem—handling hundreds or thousands of unorganized images. For family bloggers, the primary bottleneck is not writing the content, but the high friction of skimming, categorizing, and selecting a narrative subset of images representing distinct events (e.g., visits to specific landmarks, meals, transit periods).

This document outlines the architecture, design, and implementation roadmap for a native macOS application. The app leverages local system frameworks (**PhotoKit**, **Vision**, and **CoreMedia**) to automatically ingest, cluster, and prep vacation photos for rapid curation and direct markdown-based blog publishing.

---

## 2. Core Problem & Product Vision
* **The Problem:** Existing photo tools (Apple Photos, Adobe Lightroom) focus on library management or high-fidelity editing. They lack specific workflows for *subtractive curation* (rapidly discarding 90% of photos to find the 10% that tell a story) and do not bridge the gap between image files and markdown-based web publishing.
* **The Vision:** A lightweight, blazing-fast, privacy-first macOS utility that scans a folder or photo library selection, automatically breaks the timeline into logical "Event Clusters" using time and location heuristics, and offers a highly efficient keyboard-driven UI to select, rename, and export optimized assets directly into a blog repository.

---

## 3. System Architecture & Pipeline

```
[ Raw Photo Source ] (Folder or System Library)
         │
         ▼
┌────────────────────────────────────────┐
│ 1. Metadata Ingestion Engine           │ --> Extracts Timestamps, GPS, Dimensions
└────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────┐
│ 2. Spatio-Temporal Clustering Engine  │ --> Applies Rolling Time-Gap & Geofencing
└────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────┐
│ 3. Local Semantic Refinement (Vision)  │ --> Scene Classification & Duplicate Stacking
└────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────┐
│ 4. Keyboard-Driven SwiftUI Workspace   │ --> Split-Pane Curation & Selection
└────────────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────┐
│ 5. Automated Blog Export Pipeline       │ --> WebP Conversion, EXIF Stripping, Markdown
└────────────────────────────────────────┘
```

### Step 1: Ingestion & Metadata Scan
* **Mechanisms:** Dual support for direct File System directories (via `FileManager` and `CGImageSource`) or native System Photo Library access via **PhotoKit** (`PHAsset`).
* **Data Extraction:** Read lightweight metadata entries without loading full image data into memory:
    * `CreationDate` (Standardized to UTC/Local offset)
    * `Location` (CLLocation coordinate latitude/longitude)
    * `PixelDimensions` (For orientation and asset scaling)

### Step 2: Spatio-Temporal Clustering Engine
Photos are grouped chronologically using a deterministic, rolling threshold algorithm:
* **Temporal Threshold ($\Delta t$):** A configurable boundary (default: 90–120 minutes) where a break in shooting signals a transition between activities.
* **Spatial Geofence ($\Delta d$):** A geographical boundary (default: 500 meters) calculated using the Haversine formula. If the coordinate distance between consecutive photos shifts dramatically even within the time window (e.g., rapid vehicle transit), a new event is proposed.
* **Mathematical Representation:**
    An event boundary is injected between Photo $P_i$ and Photo $P_{i+1}$ if:
    $$\Delta t = t_{i+1} - t_i > T_{threshold}$$
    $$	ext{OR}$$
    $$\Delta d = 	ext{distance}(L_{i+1}, L_i) > D_{threshold}$$

### Step 3: Local Semantic Refinement
To clean up clusters before presenting them to the user, the app utilizes native Apple Silicon hardware acceleration:
* **Scene Classification:** Using macOS’s **Vision Framework (`VNClassifyImageRequest`)**, the app scans images in the background to detect stark content shifts within a single time cluster (e.g., transitioning from an indoor restaurant scene to an outdoor park landscape) to suggest sub-events.
* **Burst & Near-Duplicate Stacking:** Calculates image feature similarity vectors. Consecutive images with high similarity (>95%) are collapsed into a single "Visual Stack," preserving interface cleanliness and allowing the user to select the single best frame.

### Step 4: Curation Workspace UI (SwiftUI)
A highly responsive, split-pane macOS desktop interface:
* **Left Sidebar (Event Navigator):** A vertical timeline showing chronological event blocks with metadata badges (e.g., `"Event 3: Yosemite Valley - 42 photos, 2.5 hours"`).
* **Main Canvas (Fluid Grid):** Displays large, aspect-ratio-preserved thumbnails of the selected event. 
* **Visual States:** Selected photos display a bright highlight border. Unselected or discarded photos are dimmed to 40% opacity to visually emphasize the narrative flow.

### Step 5: Export & Automation Pipeline
Once an event is curated, the export engine bypasses manual conversion steps:
* **Web-Friendly Downscaling:** Parallel processing converts selected raw/HEIC files into modern web standards (e.g., WebP or optimized JPEG) capped at standard container widths (e.g., 2040px wide).
* **EXIF Stripping:** Strips granular GPS data and camera serial numbers to protect family privacy prior to web uploads.
* **Markdown Synthesis:** Generates a structured `.md` snippet ready to paste into a static site generator (Hugo, Jekyll, Obsidian, etc.):
    ```markdown
    ## [Event Name] - May 24, 2026
    
    ![Image Description](./assets/images/event-name-01.webp)
    ![Image Description](./assets/images/event-name-02.webp)
    ```

---

## 4. Key UX & Interaction Design
To minimize curation fatigue, the core interface operates completely mouse-free:

| Key Binding | Action |
| :--- | :--- |
| `Up / Down Arrow` | Navigate between event groups in the sidebar |
| `Left / Right Arrow` | Traverse thumbnails within the active grid |
| `Spacebar` | Toggle asset selection (Include / Exclude from blog post) |
| `Return` | Rename the current Event group (re-propagates to file prefixes) |
| `⌘ + E` | Trigger background processing and export for the active event |

---

## 5. Development Roadmap & Milestones

### Phase 1: Core Engine & Data Layer (Weeks 1-2)
* Implement `PhotoAsset` structures and local disk parsing logic.
* Develop the core temporal-spatial clustering algorithm with unit tests confirming boundary splits.
* Validate memory-efficient extraction of metadata from large directories.

### Phase 2: Native UI & Layout (Weeks 3-4)
* Build the split-pane SwiftUI layout optimized for macOS 14/15 window behaviors.
* Implement custom lazy-loading grid layouts to ensure scrolling remains fluid (60fps+) even with 1,000+ items loaded.
* Integrate full keyboard shortcut responders.

### Phase 3: Vision Framework & Export Integration (Weeks 5-6)
* Integrate background `VNClassifyImageRequest` operations to identify near-duplicates and auto-select sharpest targets.
* Build the export pipeline utilizing `AVFoundation` / `CoreGraphics` for fast WebP encoding.
* Add Markdown template configuration settings.

---

## 6. Future Extensions (Local AI Enhancements)
Given the native macOS ecosystem architecture, long-term enhancements can tie directly into local computing workflows:
* **Local VLM Captioning:** Pass selected photos to a locally running Vision-Language Model (via Ollama or Apple MLX) to generate natural language alt-text and initial descriptive draft paragraphs for the blog post automatically.
* **Obsidian Vault Plugin Integration:** Enable the app to save assets directly inside a targeted Obsidian vault, updating the blog index automatically.
