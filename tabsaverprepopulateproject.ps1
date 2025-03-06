# Filename: setup.ps1
# Usage:
#   1. Open PowerShell in the folder where this script resides.
#   2. Run: .\setup.ps1
#   3. A new folder "tab-session-saver" will be created, with all extension files.

# Create the extension directory
New-Item -ItemType Directory -Path "tab-session-saver" -Force | Out-Null

# Create 'manifest.json'
Set-Content -Path "tab-session-saver\manifest.json" -Value @"
{
  "manifest_version": 2,
  "name": "Tab Session Saver",
  "version": "1.0",
  "description": "Save and restore browsing sessions (open tabs) with local encryption.",
  "permissions": [
    "tabs",
    "downloads",
    "storage"
  ],
  "incognito": "spanning",
  "browser_action": {
    "default_title": "Tab Session Saver",
    "default_popup": "popup.html"
  },
  "background": {
    "scripts": ["background.js"]
  }
}
"@

# Create 'background.js'
Set-Content -Path "tab-session-saver\background.js" -Value @"
let encryptionKey = null;

// On extension startup, load or create the encryption key
(async function initKey() {
  try {
    const storedKey = (await browser.storage.local.get("sessionEncryptionKey")).sessionEncryptionKey;
    if (storedKey) {
      // If found, import it as CryptoKey
      encryptionKey = await importKey(storedKey);
      console.log("Loaded existing encryption key from storage.");
    } else {
      // Generate a new key
      encryptionKey = await generateKey();
      console.log("Generated new encryption key.");

      // Export and store it
      const rawKey = await exportKey(encryptionKey);
      await browser.storage.local.set({ sessionEncryptionKey: rawKey });
      console.log("Stored new encryption key in extension storage.");
    }
  } catch (err) {
    console.error("Error initializing encryption key:", err);
  }
})();

// Generate a new AES-GCM key
async function generateKey() {
  return await crypto.subtle.generateKey(
    {
      name: "AES-GCM",
      length: 256
    },
    true,
    ["encrypt", "decrypt"]
  );
}

// Export the key as raw ArrayBuffer
async function exportKey(key) {
  return await crypto.subtle.exportKey("raw", key);
}

// Import the raw key from storage
async function importKey(buffer) {
  return await crypto.subtle.importKey(
    "raw",
    buffer,
    {
      name: "AES-GCM",
      length: 256
    },
    true,
    ["encrypt", "decrypt"]
  );
}

// Helper to encrypt data with AES-GCM
async function encryptData(data) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encoded = new TextEncoder().encode(data);
  const ciphertext = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, encryptionKey, encoded);

  const combined = new Uint8Array(iv.byteLength + ciphertext.byteLength);
  combined.set(iv, 0);
  combined.set(new Uint8Array(ciphertext), iv.byteLength);

  return btoa(String.fromCharCode(...combined));
}

// Helper to decrypt data with AES-GCM
async function decryptData(base64) {
  const bytes = new Uint8Array([...atob(base64)].map(char => char.charCodeAt(0)));
  const iv = bytes.slice(0, 12);
  const ciphertext = bytes.slice(12);

  const decrypted = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, encryptionKey, ciphertext);
  return new TextDecoder().decode(decrypted);
}

// Handle messages from popup
browser.runtime.onMessage.addListener(async (message) => {
  if (message?.command === "encrypt") {
    try {
      return await encryptData(message.plainText);
    } catch (error) {
      console.error("Error encrypting data:", error);
      throw error;
    }
  } else if (message?.command === "decrypt") {
    try {
      return await decryptData(message.cipherText);
    } catch (error) {
      console.error("Error decrypting data:", error);
      throw error;
    }
  }
});
"@

# Create 'popup.html'
Set-Content -Path "tab-session-saver\popup.html" -Value @"
<!DOCTYPE html>
<html>
  <head>
    <meta charset=\"utf-8\" />
    <title>Tab Session Saver</title>
  </head>
  <body>
    <button id=\"saveTabs\">Save Tabs</button>
    <button id=\"restoreTabs\">Restore Tabs</button>
    <input
      type=\"file\"
      id=\"fileInput\"
      accept=\".json,application/json\"
      style=\"display: none;\"
    />
    <script src=\"popup.js\"></script>
  </body>
</html>
"@

# Create 'popup.js'
Set-Content -Path "tab-session-saver\popup.js" -Value @"
// SAVE TABS
document.getElementById('saveTabs').addEventListener('click', async () => {
  try {
    // 1. Get all open tabs
    const tabs = await browser.tabs.query({});
    // 2. Extract URLs
    const urls = tabs.map(tab => tab.url);
    // 3. Turn into JSON
    const plainText = JSON.stringify(urls);
    // 4. Encrypt via background script
    const cipherText = await browser.runtime.sendMessage({
      command: 'encrypt',
      plainText
    });
    // 5. Download as file
    const blob = new Blob([cipherText], { type: 'application/json' });
    const blobUrl = URL.createObjectURL(blob);

    await browser.downloads.download({
      url: blobUrl,
      filename: 'my_tabs_encrypted.json',
      saveAs: true
    });

    console.log('Tabs encrypted and saved.');
  } catch (error) {
    console.error('Error saving tabs:', error);
  }
});

// RESTORE TABS
document.getElementById('restoreTabs').addEventListener('click', () => {
  document.getElementById('fileInput').click();
});

document.getElementById('fileInput').addEventListener('change', async (event) => {
  const file = event.target.files[0];
  if (!file) return;

  try {
    // Read file
    const fileText = await file.text();
    // Decrypt
    const decrypted = await browser.runtime.sendMessage({
      command: 'decrypt',
      cipherText: fileText
    });
    const urls = JSON.parse(decrypted);

    if (Array.isArray(urls)) {
      // Open each URL
      for (let url of urls) {
        await browser.tabs.create({ url });
      }
      console.log('Tabs restored successfully.');
    } else {
      console.error('Decrypted data is not an array of URLs.');
    }
  } catch (error) {
    console.error('Error restoring tabs:', error);
  }
});
"@

Write-Host "Extension files created in 'tab-session-saver' folder."
Write-Host "No further dependencies are required. If needed, install Firefox for testing."
