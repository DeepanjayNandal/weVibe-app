import admin from "firebase-admin";

export const bucket = admin.storage().bucket();
export default admin;