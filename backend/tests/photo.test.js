import axios from "axios";

const BASE_URL = "http://localhost:3000";
const TOKEN = "Insert_firebase_token";

// Dummy image 
const DUMMY_IMAGE = Buffer.from([
  0xff, 0xd8, 0xff, 0xdb, 0x00, 0x43, 0x00, 0xff, 0xd9,
]); // minimal JPEG

let photoId = null;

/**
 * Step 1: Get Upload URL
 */
async function getUploadURL() {
  console.log("Step 1: getUploadURL");

  const res = await axios.post(
    `${BASE_URL}/users/profile/photos/upload-url`,
    {
      mimeType: "image/jpeg",
      sizeBytes: DUMMY_IMAGE.length,
    },
    {
      headers: {
        Authorization: `Bearer ${TOKEN}`,
      },
    }
  );

  console.log("Upload URL received");

  return res.data; // { photoId, uploadURL }
}

/**
 * Step 2: Upload to GCS (signed URL)
 */
async function uploadToGCS(uploadURL) {
  console.log("Step 2: Uploading to GCS");

  const res = await axios.put(uploadURL, DUMMY_IMAGE, {
    headers: {
      "Content-Type": "image/jpeg",
    },
  });

  if (res.status !== 200) {
    throw new Error("Upload failed");
  }

  console.log("Upload successful");
}

/**
 * Step 3: Finalize
 */
async function finalizeUpload(photoId) {
  console.log("Step 3: Finalize");

  const res = await axios.post(
    `${BASE_URL}/users/profile/photos/finalize`,
    {
      photoId,
      order: 0,
    },
    {
      headers: {
        Authorization: `Bearer ${TOKEN}`,
      },
    }
  );

  console.log("Finalized:", res.data);

  return res.data;
}

/**
 * Step 4: Reorder
 */
async function reorderPhotos(photoId) {
  console.log("Step 4: Reorder");

  const res = await axios.patch(
    `${BASE_URL}/users/profile/photos/reorder`,
    {
      orderedPhotoIds: [photoId],
    },
    {
      headers: {
        Authorization: `Bearer ${TOKEN}`,
      },
    }
  );

  console.log("Reorder success");
}

/**
 * Step 5: Delete
 */
async function deletePhoto(photoId) {
  console.log("Step 5: Delete");

  const res = await axios.delete(
    `${BASE_URL}/users/profile/photos/${photoId}`,
    {
      headers: {
        Authorization: `Bearer ${TOKEN}`,
      },
    }
  );

  if (res.status === 204) {
    console.log("Delete success");
  }
}

/**
 * MAIN RUNNER
 */
async function runTest() {
  try {
    console.log("Starting Photo Pipeline Test\n");

    // 1
    const { photoId: id, uploadURL } = await getUploadURL();
    photoId = id;

    // 2
    await uploadToGCS(uploadURL);

    // 3
    await finalizeUpload(photoId);

    // 4
    await reorderPhotos(photoId);

    // 5
    await deletePhoto(photoId);

    console.log("\n ALL TESTS PASSED");
  } catch (err) {
    console.error("\n TEST FAILED");
    console.error(err.response?.data || err.message);
  }
}

runTest();