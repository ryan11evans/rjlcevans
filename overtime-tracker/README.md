# overtime-tracker

iOS app for two federal Schedule 1-A estimates, tax years 2025–2028: the FLSA overtime premium ("No Tax on Overtime") and qualified passenger-vehicle loan interest.

Estimates only, not tax advice or tax-prep software.

The home-screen name is `CFBundleDisplayName` in [`NewDeductions/App/Info.plist`](NewDeductions/App/Info.plist) (currently "New Deductions"). That plist string is the one to change. The Xcode target stays `NewDeductions`.

## Open and build

Xcode 15 or later, deployment target iOS 17. No third-party packages. `OvertimeCore` is a local Swift package the project already references.

1. Open `overtime-tracker/NewDeductions.xcodeproj`.
2. Select the `NewDeductions` scheme and an iPhone simulator.
3. Run. Signing is automatic, team `9B9PTBR9A2`, bundle id `com.rjlcevans.newdeductions`.

The `.xcodeproj` is committed, so a plain Xcode build does not need XcodeGen. `project.yml` matches it if you regenerate:

```bash
brew install xcodegen
cd overtime-tracker
xcodegen generate
```

After regenerating, confirm `MARKETING_VERSION` is still `1.0` and `CURRENT_PROJECT_VERSION` is still `1` in both `project.yml` and `project.pbxproj`. Add any new source file in both files. `NewDeductions/App/Info.plist` is the app's Info.plist (`INFOPLIST_FILE`); it is not a resource.

### Tests

`NewDeductionsTests` (bundle id `com.rjlcevans.newdeductions.tests`) compiles the `OvertimeCore` package tests and hosts them in the app:

```bash
xcodebuild test \
  -project overtime-tracker/NewDeductions.xcodeproj \
  -scheme NewDeductions \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

On a Mac, `swift test` inside `overtime-tracker/OvertimeCore` runs the same tests.

The iOS app target needs Xcode. `swift test` inside `overtime-tracker/OvertimeCore` runs the package tests without the app.

The App Store listing name is **New Deductions: OT + Car Loan**. The home-screen name stays `CFBundleDisplayName` ("New Deductions"). Do not put the longer name in that plist key.

Privacy, terms, and support are static pages in this folder. GitHub Pages on `main` serves them at:

- https://rjlcevans.com/overtime-tracker/privacy.html
- https://rjlcevans.com/overtime-tracker/terms.html
- https://rjlcevans.com/overtime-tracker/support.html

Settings links all three. There is no tracker and no external script on those pages.

## What this version does

- Xcode project and the local `OvertimeCore` package
- SwiftData models: Employer, Week, Shift, TaxProfile, Vehicle, VehicleLoan. The store is local only (`cloudKitDatabase: .none`, no iCloud entitlement)
- Onboarding: eligibility, base rate and workweek start day, filing status / estimated MAGI / bracket, and the disclaimer the user has to accept before a profile is saved
- Overtime tab for the one "Primary job" employer: a year dial and a workweek log (add, edit, delete), including weeks back to the workweek that contains January 1 of the tax year. Qualified premium is only the 0.5× FLSA premium. The year-end figure is a run-rate: average qualified premium of the logged weeks × 52 (see `OvertimeCalculator.projectedYearEndPremium`). The deduction and tax-saved figures apply the cap and MAGI phase-out to that projection. Every figure is labeled as an estimate
- Car loan tab: 17-character VIN with the ISO check digit, then one NHTSA vPIC `DecodeVinValues` call. US `PlantCountry` is US final assembly. Any other country is "Not eligible". A blank or failed lookup is "Unknown, check the door-jamb label". The checklist, amortization, Form 1098-VLI override, and deduction are in the same tab
- W-2 Box 12 code TT compared with the log, a Form W-4 line 4(b) suggestion (the two estimated deductions added together), and a Summary tab with CSV export
- StoreKit 2 paywall. Free tier: VIN check and the current overtime week. Everything else is locked. Products, also listed in `NewDeductions/Products.storekit`: `com.rjlcevans.newdeductions.yearly` ($19.99/year, auto-renews through Apple) and `com.rjlcevans.newdeductions.lifetime` ($29.99, non-consumable). The scheme's Run action points at that storekit file for local testing
- Settings: the disclaimer, an editable tax profile (filing status, estimated MAGI, 10/12/22/24/32/35/37 bracket), restore purchases, the legal links, and the source list (those links open in Safari; the app does not fetch them)

Not in this version:

- PDF export
- v1.1: Live Activity shift clock, VIN camera scan, multiple-employer UI, iCloud

Optional shift-by-shift time entry is not in the week editor. Hours are entered for the workweek. The `Shift` model is unchanged.

### Schema added since week 1

SwiftData optional properties, so a week-1 store can open without a custom migration:

- `Vehicle.gvwrPounds: Int?`
- `Vehicle.userConfirmedGVWRUnderLimit: Bool?`
- `VehicleLoan.salvageOrScrap: Bool?`
- `VehicleLoan.relatedPartyLender: Bool?`

`Employer.codeTT` and `VehicleLoan.actualInterest` are still computed over JSON `Data`. Assign the whole dictionary, or call `setCodeTT` / `setActualInterest`.

## Notes for the next weeks

- Onboarding creates one employer named "Primary job" so the hourly rate and workweek start day have a model to live on (`Employer.defaultRate`, `Employer.workweekStartsOn`). Overtime is per employer; hours are not combined across jobs.
- `TaxProfile` also stores `isHourlyNonExempt`, `paidOvertimeOver40`, and `acceptedDisclaimer`. The plan's model snippet did not list those onboarding answers.
- The plan shows `codeTT` and `actualInterest` as `[Int: Decimal]`. SwiftData on iOS 17 does not persist that dictionary, so each one is a computed property over a JSON `Data` field (`codeTTData`, `actualInterestData`). Assign the whole dictionary, or call `setCodeTT` / `setActualInterest`. A subscript write on the getter's copy does not save.
- v1.0 opts out of iCloud. Turning sync on in v1.1 may need a new store or a migration.
- The app icon is a placeholder.
