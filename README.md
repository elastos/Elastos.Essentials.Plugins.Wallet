# elastos-essentials-plugins-wallet

This plugin defines a global `cordova.walletManager` object, which provides an API for wallet library.

Although in the global scope, it is not available until after the `deviceready` event.

```js
document.addEventListener("deviceready", onDeviceReady, false);
function onDeviceReady() {
    console.log(walletManager);
}
```
---

## Supported Platforms

- Android
- iOS