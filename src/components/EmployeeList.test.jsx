import {render, screen} from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import EmployeeList from "./EmployeeList.jsx";

const sam = {id: 2, name: "Sam Sony", jobTitle: "Web-Architect", profilePictureFilename: null};
const gino = {id: 3, name: "Gino Brambilla", jobTitle: "Design-Engineer", profilePictureFilename: "abc.png"};

function jsonResponse(body, status = 200) {
  return Promise.resolve({ok: status < 400, status, json: () => Promise.resolve(body)});
}

function mockApi({upload}) {
  globalThis.fetch = vi.fn((url, options) =>
    options?.method === "POST" ? upload() : jsonResponse([sam, gino])
  );
}

test("lists employees and shows a photo only for those who have one", async () => {
  mockApi({});

  render(<EmployeeList/>);

  expect(await screen.findByText("Sam Sony")).toBeInTheDocument();
  expect(screen.getByText("Design-Engineer")).toBeInTheDocument();
  expect(screen.getByAltText("Photo of Gino Brambilla")).toHaveAttribute(
    "src",
    expect.stringContaining("v1/employees/3/photo?v=abc.png")
  );
  expect(screen.queryByAltText("Photo of Sam Sony")).not.toBeInTheDocument();
});

test("uploads the selected file and shows the new photo", async () => {
  mockApi({upload: () => jsonResponse({...sam, profilePictureFilename: "new.png"})});
  render(<EmployeeList/>);
  const file = new File(["png"], "sam.png", {type: "image/png"});

  await userEvent.upload(await screen.findByLabelText("Upload photo for Sam Sony"), file);

  expect(await screen.findByAltText("Photo of Sam Sony")).toHaveAttribute(
    "src",
    expect.stringContaining("v1/employees/2/photo?v=new.png")
  );
  const [url, options] = globalThis.fetch.mock.calls.find(([, init]) => init?.method === "POST");
  expect(url).toContain("v1/employees/2/photo");
  expect(options.body.get("file")).toBe(file);
});

test("shows the error reported by the backend when the upload fails", async () => {
  mockApi({upload: () => jsonResponse({error: "Zugriff auf den Bild-Storage verweigert"}, 502)});
  render(<EmployeeList/>);

  await userEvent.upload(
    await screen.findByLabelText("Upload photo for Sam Sony"),
    new File(["png"], "sam.png", {type: "image/png"})
  );

  expect(await screen.findByRole("alert")).toHaveTextContent("Zugriff auf den Bild-Storage verweigert");
  expect(screen.queryByAltText("Photo of Sam Sony")).not.toBeInTheDocument();
});

test("shows an error instead of an empty list when employees cannot be loaded", async () => {
  globalThis.fetch = vi.fn(() => jsonResponse({}, 503));

  render(<EmployeeList/>);

  expect(await screen.findByText(/Employees could not be loaded/)).toBeInTheDocument();
});
