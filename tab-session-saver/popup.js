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
