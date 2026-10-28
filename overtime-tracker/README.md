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

**This tree was not compiled.** The machine that added it has no Xcode and no Swift toolchain. The first build is on a Mac.

## Week 1

Done:

- Xcode project and the local `OvertimeCore` package (both calculators and their tests)
- SwiftData models: Employer, Week, Shift, TaxProfile, Vehicle, VehicleLoan. The store is local only (`cloudKitDatabase: .none`, no iCloud entitlement)
- Tabs: Overtime, Car Loan, Summary, Settings. The first three are placeholders
- Onboarding: eligibility, base rate and workweek start day, filing status / estimated MAGI / bracket, and the disclaimer the user has to accept before a profile is saved
- Settings: the disclaimer, the saved profile and primary employer, and the source list (those links open in Safari; the app does not fetch them)

Not in this version:

- Week 2: overtime week log and home dial
- Week 3: VIN entry, check digit, NHTSA decode
- Week 4: W-2 Box 12 code TT, W-4 helper, Form 1098-VLI actual interest
- Week 5: CSV and PDF export, StoreKit paywall, hosted privacy policy
- v1.1: Live Activity shift clock, VIN camera scan, multiple-employer UI, iCloud

## Notes for the next weeks

- Onboarding creates one employer named "Primary job" so the hourly rate and workweek start day have a model to live on (`Employer.defaultRate`, `Employer.workweekStartsOn`). Overtime is per employer; hours are not combined across jobs.
- `TaxProfile` also stores `isHourlyNonExempt`, `paidOvertimeOver40`, and `acceptedDisclaimer`. The plan's model snippet did not list those onboarding answers.
- The plan shows `codeTT` and `actualInterest` as `[Int: Decimal]`. SwiftData on iOS 17 does not persist that dictionary, so each one is a computed property over a JSON `Data` field (`codeTTData`, `actualInterestData`). Assign the whole dictionary, or call `setCodeTT` / `setActualInterest`. A subscript write on the getter's copy does not save.
- v1.0 opts out of iCloud. Turning sync on in v1.1 may need a new store or a migration.
- The app icon is a placeholder.
