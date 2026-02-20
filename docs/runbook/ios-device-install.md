# iPhone Device Install (Xcode)

This is the closest flow to a formal install package while still using local development build.

## 1. Generate native iOS project

```bash
cd /Users/camlostshi/Documents/ReToDoScheduler/apps/mobile
npm run prebuild:ios
```

## 2. Open Xcode workspace

```bash
cd /Users/camlostshi/Documents/ReToDoScheduler/apps/mobile
npm run open:xcode
```

Open `ReToDoScheduler` target, then configure:

- Signing & Capabilities -> Team: your Apple account/team
- Bundle Identifier: `com.camlostshi.retodoscheduler` (change if it conflicts)
- Signing Certificate: Apple Development
- Automatically manage signing: enabled

## 3. Install to iPhone 15 Pro

- Connect iPhone by cable (or trusted wireless debugging)
- Select your iPhone as the run target in Xcode
- Press `Run` (`Cmd + R`)

## 4. First-launch trust checks

If iOS blocks launch:
- Settings -> Privacy & Security -> Developer Mode (enable)
- Settings -> General -> VPN & Device Management -> trust your development certificate

## 5. Toward production/TestFlight

When ready:
- In Xcode, `Product -> Archive`
- Then `Distribute App -> App Store Connect -> Upload`
- Increment build number before each upload (`ios.buildNumber` in app config)
