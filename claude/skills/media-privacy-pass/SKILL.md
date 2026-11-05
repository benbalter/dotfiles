---
name: media-privacy-pass
description: Privacy pass for photos, videos, and screenshots before they go anywhere public (a blog post, README, issue, PR, or social post). Strips GPS and other metadata, checks frames for kids, bystanders, and details that locate the house, drops audio, and converts iPhone color to sRGB. Use before publishing, attaching, or committing any image or video.
---

# Media privacy pass

Phone photos carry my home's GPS coordinates, and frames show more than the subject. Run every step on every file headed somewhere public, then tell me what you changed.

- **Metadata.** Strip it from every exported file (`exiftool -all=` for stills; for video, map only the video stream with `-map_metadata -1`, which also drops Apple's timed location track), then verify with `exiftool -a -G1 -ee -gps:all -xmp:all <file>` coming back empty. Format conversions (`sips`, `magick`) carry GPS forward unless stripped.
- **People.** No kids in frame at all, and crop out bystanders, even blurry ones. For a Live Photo or video, check every frame, not just the still.
- **The house.** Look at full resolution for house numbers, street signs, the front door, and reflections in shiny surfaces.
- **Screenshots.** Crop the status bar and anything else that leaks household detail (Live Activities, now-playing art, notifications).
- **Audio.** Drop it (`-an`) unless I asked for it, and confirm with `ffprobe` that no audio stream is left.
- **Color.** iPhone images are Display P3, and stripping drops the profile without converting the pixels, so the colors render dull. Convert to sRGB (`-profile "/System/Library/ColorSync/Profiles/sRGB Profile.icc"`) before `-strip`.
