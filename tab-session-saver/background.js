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
