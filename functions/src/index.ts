import * as admin from "firebase-admin";
admin.initializeApp();

// Export all functions
export { findNearbyDrivers } from "./findNearbyDrivers";
export { onDriverAccept } from "./onDriverAccept";
export { onDriverTimeout } from "./onDriverTimeout";
export { findNearbyHospitals } from "./findNearbyHospitals";
export { onHospitalAccept } from "./onHospitalAccept";
export { onHospitalTimeout } from "./onHospitalTimeout";
export { updateDriverLocation } from "./updateDriverLocation";
