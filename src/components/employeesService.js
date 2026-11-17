const baseUrl = import.meta.env.VITE_API_BASE_URL || "http://localhost:8080/";

export async function getEmployees() {
  const response = await fetch(`${baseUrl}v1/employees`);
  if (response.ok) return response.json();
  throw new Error(await errorMessage(response));
}

// The filename changes with every upload, so using it as a query parameter
// makes the browser fetch the new photo instead of showing a cached one.
export function employeePhotoUrl(employee) {
  const version = encodeURIComponent(employee.profilePictureFilename);
  return `${baseUrl}v1/employees/${employee.id}/photo?v=${version}`;
}

export async function uploadEmployeePhoto(id, file) {
  const body = new FormData();
  body.append("file", file);
  const response = await fetch(`${baseUrl}v1/employees/${id}/photo`, {method: "POST", body});
  if (response.ok) return response.json();
  throw new Error(await errorMessage(response));
}

async function errorMessage(response) {
  try {
    const body = await response.json();
    if (body?.error) return body.error;
  } catch {
    // The response had no JSON body; fall back to the status code below.
  }
  return `Request failed (HTTP ${response.status})`;
}
