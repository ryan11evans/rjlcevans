# Vision Simulator iOS app

Capacitor 6 shell for **Vision Simulator by Dr. Evans** (`com.rjlcevans.visionsim`). The app does not bundle the simulator. `capacitor.config.json` sets `server.url` to `https://rjlcevans.com/vision-simulator/`, and every installed copy — including older versions — loads that page.

Version in this project: **4.1 (15)**. The live App Store build is 4.0. Build 4.1 (14) is already uploaded. The next upload must be build 15 or App Store Connect will reject it as a duplicate.

## How to safely ship changes

`rjlcevans.com` is **GitHub Pages**, legacy mode, publishing the **`main` branch, folder `/`**. A push to `main` is the production deploy. No other branch is published. There is no Netlify or Vercel project. Do not push web changes straight to `main`, and do not merge until you have looked at them somewhere else first.

### What goes live with the website, and what needs a new App Store build

| Change | Reaches people when |
|---|---|
| `vision-simulator/` (the gate, copy, Pro behavior) | You push that folder to `main`. Every installed app loads it on next open. |
| In-app review prompt | Only after a new binary is approved. The website calls `InAppReview` only when the native plugin is installed, so older apps ignore it. |
| Staging URL inside a binary | Only the **App Staging** scheme. The **App** scheme (Debug and Release) stays on the production URL. |

The browser gate is safe for installed apps: the page runs the simulator when it sees Capacitor (including older builds), Cordova, the purchase plugin, or Capacitor's `bridge` message handler. If detection throws or the script is missing, it runs the simulator. A normal browser gets the App Store page instead.

### Staging first

1. On the feature branch, preview in a browser (gate) and with Capacitor simulated (simulator). From the repo root:

   ```sh
   python3 -m http.server 8080
   ```

   Open `http://localhost:8080/vision-simulator/` and `http://localhost:8080/vision-simulator/?stay=1` (the `stay` flag skips the App Store redirect). Add `?stay=1` any time you want to read the page without leaving it.

   `node vision-simulator/test/shell-detect.test.js` checks the fail-open rules with no extra packages. `vision-simulator/test/gate-behavior.test.js` needs Playwright and covers a normal browser, a Capacitor app, a late bridge, and a missing detection script.

2. Publish a staging copy **without** changing the live simulator. On the feature branch, build the staging folder, then put only that folder on a branch cut from `main`:

   ```sh
   ./scripts/publish-vision-simulator-staging.sh
   git add vision-simulator-staging
   git commit -m "Add Vision Simulator staging snapshot"
   git fetch origin
   git checkout -B publish-vision-staging origin/main
   git checkout FEATURE_BRANCH -- vision-simulator-staging
   git status
   ```

   `git status` must list `vision-simulator-staging/` and must not list `vision-simulator/`. Commit and push `publish-vision-staging`. Open a pull request into `main` that contains only that folder. When it merges, GitHub Pages serves `https://rjlcevans.com/vision-simulator-staging/`. The live app keeps loading `/vision-simulator/`.

   Do not use `git checkout main -- vision-simulator` on the feature branch. That would replace the branch's simulator with the live one.

3. On a Mac, in `vision-simulator-app/`:

   ```sh
   npm install
   npx cap sync ios
   ```

   `cap sync` runs `pod install` and pulls in `CapacitorCommunityInAppReview`. Open `ios/App/App.xcworkspace` (the workspace, not the xcodeproj alone).

   Xcode 27 only archives an iOS deployment target of 15.0 or newer. The App target is set to 15.0, and the Podfile `post_install` hook sets 15.0 on every pod target. The App target signing team is `9B9PTBR9A2`. A normal Archive in Xcode uses those settings; you do not need the `IPHONEOS_DEPLOYMENT_TARGET=15.0` and `DEVELOPMENT_TEAM=9B9PTBR9A2` overrides that were required to upload build 14. The next binary requires iOS 15 or later. Phones still on iOS 13 or 14 keep the already-installed app.

4. Scheme **App Staging** (configuration Staging) rewrites the bundled `server.url` to `https://rjlcevans.com/vision-simulator-staging/`. Run that on a device or upload it to TestFlight. Scheme **App**, Archive, configuration **Release**, stays on production. Do not upload an **App Staging** archive to the App Store.

5. Test on iPhone and iPad: camera, a sample photo, free conditions, a Pro condition, Compare, Combine, purchase, and Restore. Then turn Compare on three separate times and confirm the system review dialog is allowed to appear (Apple may still choose not to show it).

6. Promote. Copy `vision-simulator-staging/` back onto `vision-simulator/` (or merge the branch that already has the final `vision-simulator/` files) and push `main`. Tag that commit, for example `vision-simulator-web-YYYY-MM-DD`, so you can find it later.

7. Ship the new binary from scheme **App**, Release. In App Store Connect the version is 4.1 and the build is 15 (build 14 is already uploaded). Add review notes that the app now asks for a rating with `SKStoreReviewController` after the third Compare use.

### Roll back

- **Website.** `git revert` the `main` commit that changed `vision-simulator/` and push `main`. Pages rebuilds from that. Installed apps pick up the previous page on next launch. Reverting does not affect a binary that is already approved.
- **A bad staging push.** Revert the commit that changed `vision-simulator-staging/` only. Production is untouched.
- **A bad binary.** In App Store Connect, remove the build from review, or release the previous version again. You cannot roll a native plugin back through the website. The website's review call already does nothing on binaries that don't have the plugin.

### Pro purchases

Browsers no longer run the simulator, so the old free-on-the-web unlock is gone.

Installed apps that include `cordova-plugin-purchase` are unchanged: Pro stays locked until StoreKit reports the non-consumable `com.rjlcevans.visionsim.pro`, Restore still calls `restorePurchases()`, and `localStorage` key `vs_isPro` still remembers the last answer so a paying user is not locked while the store loads. There is no receipt server. Clearing the app's website data asks StoreKit again the next time the plugin starts; Restore brings a purchase back.

**Older binaries that do not contain the purchase plugin stay fully unlocked.** They are the builds from before Pro existed. They have no purchase sheet and no restore, so putting a paywall on them would take features away with no way to pay. That path is deliberate. Closing it would not be safe.

Someone who spoofs `window.Capacitor` in a desktop browser can still open the simulator and, without the purchase plugin, is treated like those older binaries. That is the same fail-open rule that protects real app users.

## Native review prompt

`@capacitor-community/in-app-review` 6.0.0 (Capacitor 6) calls `SKStoreReviewController.requestReview()`. The web page counts Compare activations in `vs_compareUses` and calls the plugin once, on the third one, only if `Capacitor.isPluginAvailable('InAppReview')` is true. Apple still rate-limits the dialog. The prompt does not show in the simulator or in a browser.
