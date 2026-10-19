# Vision Simulator: vertical promo videos (JOB 1)

Three 9:16 clips, 1080×1920, 30 fps, H.264 with a silent AAC track. Captions are burned in, and the hook is the first on-screen text.
Every clip ends on the same card: app icon, "Vision Simulator", "Free on the App Store", the clip's CTA, and
"Education only, not a diagnosis. See your eye doctor."
**No price appears anywhere in the videos or in these captions.**
All footage is real output from the live app (iOS-emulated). There are no patients, no clinic, and no people.

Audio: the files ship silent. Add a quiet, neutral trending sound on the platform. No voiceover is needed because every beat is captioned.

---

## V1 · `v1-cataract-night.mp4` (17.0 s)

**On-screen hook:** Your mom says she's "fine to drive at night." This is what cataracts actually do.

**Beats:** normal night street → compare wipe "Cataract: halos around every headlight" → severity ramp "As it worsens: haze, glare, faded color" → split "Left: normal · Right: cataract" → end card.

**On-screen CTA:** Search "Vision Simulator Eye Disease"

**Post caption:**
> Your mom says she's "fine to drive at night." Cataracts don't feel dramatic from the inside. They creep in as glare, halos and faded color, so people adapt without noticing. If night driving is getting harder for someone you love, an eye exam is the next step. Cataract surgery is one of the most common and successful surgeries there is.
>
> Free to try on iPhone/iPad: search "Vision Simulator Eye Disease".
> Education only, not a diagnosis. See your eye doctor.
>
> #cataracts #nightdriving #eyehealth #optometrist #agingparents #vision

**Alt text:** A night city street with headlights, shown first clearly, then through simulated cataracts, where the lights bloom into halos and the scene turns hazy and dim. A split screen compares normal vision on the left with cataract vision on the right.

---

## V2 · `v2-glaucoma.mp4` (19.0 s)

**On-screen hook:** Glaucoma steals your side vision so slowly you don't notice. Watch.

**Beats:** normal → "Early: a faint patch you won't notice" → "It spreads, often starting up top" → "Then half the view fades away" → "Late: a small island of sight" → split "Lost vision doesn't come back. Early treatment protects it." → end card.

**On-screen CTA:** Get your eye pressure checked.

**Post caption:**
> Glaucoma usually has no pain and no early symptoms. The brain fills in the gaps, so side vision can fade for years before anyone notices. Damage can't be undone, but treatment can protect what's left. That's why routine eye exams matter, especially if glaucoma runs in your family.
>
> Get your eye pressure and optic nerve checked.
> Free to try on iPhone/iPad: search "Vision Simulator Eye Disease".
> Education only, not a diagnosis. See your eye doctor.
>
> #glaucoma #eyehealth #optometrist #eyeexam #vision #silentthief

**Alt text:** A night street scene that slowly loses its edges as simulated glaucoma progresses, from a faint patch to a small central island of clear vision, followed by a split-screen comparison with normal vision.

---

## V3 · `v3-amd-menu.mp4` (17.5 s)

**On-screen hook:** This is what reading a menu looks like with macular degeneration.

**Beats:** normal menu → "Early AMD: words bend and blur in the center" → "A gray smudge sits where you look" → "Side vision stays. The center is lost." → Amsler grid "Amsler grid: straight lines bow" → end card.

**On-screen CTA:** Try it free on iPhone and iPad.

**Post caption:**
> Macular degeneration takes the center of your vision, the part you read, recognize faces and see details with. Side vision usually stays, which is why people say "I can see, I just can't read." Wavy or bent lines can be an early warning sign. If you notice it, call your eye doctor promptly.
>
> Free to try on iPhone/iPad: search "Vision Simulator Eye Disease".
> Education only, not a diagnosis. See your eye doctor.
>
> #maculardegeneration #AMD #lowvision #eyehealth #optometrist #amslergrid

**Alt text:** A restaurant menu viewed through simulated macular degeneration: the words at the center warp, blur and then disappear behind a gray smudge while the edges stay readable. An Amsler grid follows, with its central lines bowing.

---

### Notes
- The "Search 'Vision Simulator Eye Disease'" CTA assumes the planned App Store rename to "Vision Simulator: Eye Disease". The live name is still "Vision Simulator by Dr. Evans", so confirm that the search finds the app before posting, or change the CTA to "Search 'Vision Simulator Dr. Evans'".
- Menu prices are plain numbers with no currency sign. The app price ($4.99 Pro) is deliberately left out.
- Rebuild: `node capture.js` (env `PW=<playwright path>`), then `python3 make_videos.py <frames> <out>`.
