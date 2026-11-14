# iPhone and iPad privacy

The iOS and iPadOS side of the Mac's privacy settings in [`config.yml`](../config.yml). These are personal, unsupervised devices with Safari as the main browser on both, so there are three routes. Everything here applies to the iPhone and the iPad alike; do each device separately, since these settings are per device (only Safari extensions can follow you, via Share Across Devices):

- [`privacy.mobileconfig`](privacy.mobileconfig) enforces what a self-installed profile can: personalized ads, analytics sharing and app tracking requests off, and Safari's fraud warning and cross-site tracking prevention on.
- The checklist below covers the rest. Most of Safari is here, because Apple offers no profile key for these settings without supervision (enrolling the device in an MDM).
- Chrome on iOS, when it's used, gets [`chrome/policies.json`](../chrome/policies.json) at sign-in, the same as on the Mac.

## Install the profile

1. On the Mac, AirDrop `ios/privacy.mobileconfig` to the iPhone or iPad.
2. On the device: Settings → Profile Downloaded → Install. iOS calls it unverified because it isn't signed. That's expected.
3. Locked settings now show greyed out. To change one, remove the profile: Settings → General → VPN & Device Management → Privacy → Remove Profile.

After editing the file, AirDrop it again. Its UUIDs are fixed, so the new copy replaces the installed one.

## Checklist

### Safari

Safari stays the default browser here even though Chrome is the Mac's. Outside the EU, Chrome on iOS runs on Safari's engine anyway, but without fingerprint protection, Private Relay, content blockers or this profile's Safari locks. If Chrome ever took over, check Settings → Apps → Safari → Default Browser App.

Settings → Apps → Safari:

- [ ] **Advanced → Advanced Tracking and Fingerprinting Protection → All Browsing.** The Mac sets the same thing in `config.yml`. iOS defaults to private browsing only.
- [ ] **Hide IP Address → Trackers and Websites** (needs iCloud+ Private Relay; otherwise Trackers).
- [ ] **Search:** turn off Search Engine Suggestions, Safari Suggestions and Preload Top Hit. They send what you type to the search engine and to Apple before you press Go.
- [ ] **Require Face ID (or Touch ID) to Unlock Private Browsing.** The wording follows the device's biometrics.
- [ ] **Extensions:** the iOS versions of the Mac's Safari extensions (1Password, AdGuard, Dark Reader), and Kagi Search if you use Kagi on the device, as Chrome does on the Mac.

### Elsewhere

- [ ] **Privacy & Security → Analytics & Improvements:** turn off Improve Siri & Dictation and Share iCloud Analytics. The profile covers device analytics; these two have no unsupervised key.
- [ ] **Wi-Fi → (network) → Private Wi-Fi Address → Rotating** for public networks. It's set per network, and network names don't belong in this public repo.
- [ ] **Privacy & Security → Location Services:** turn off apps that don't need it, and under System Services turn off at least iPhone Analytics (iPad Analytics on the iPad) and Significant Locations.
- [ ] **Privacy & Security → Camera, Microphone, Local Network:** revoke what isn't used day to day. Only an MDM can manage these.
- [ ] **Advanced Data Protection** is an iCloud account setting, so turning it on from the Mac already covers these devices.

The Mac's firewall, AirPlay Receiver, login-window message and guest account have no iOS equivalent.
