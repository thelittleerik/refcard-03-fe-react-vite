import {useState, useEffect} from "react";
import "bootstrap/dist/css/bootstrap.min.css";
import {FontAwesomeIcon} from "@fortawesome/react-fontawesome";
import {faUser, faUpload} from "@fortawesome/free-solid-svg-icons";
import {getEmployees, uploadEmployeePhoto, employeePhotoUrl} from "./employeesService.js";

const acceptedTypes = "image/png,image/jpeg,image/webp";

function EmployeeList() {
    const [employees, setEmployees] = useState([]);
    const [loadError, setLoadError] = useState(null);

    useEffect(() => {
        getEmployees()
            .then((response) => setEmployees(response))
            .catch((error) => setLoadError(error.message));
    }, []);

    function replaceEmployee(updated) {
        setEmployees((current) => current.map((employee) => (employee.id === updated.id ? updated : employee)));
    }

    return (
        <section className="my-4">
            <div className="d-flex align-items-center justify-content-between mb-3">
                <h4 className="mb-0">Employees</h4>
                <span className="badge text-bg-secondary">{employees.length} employees</span>
            </div>

            {loadError ? (
                <p className="alert alert-danger">Employees could not be loaded: {loadError}</p>
            ) : employees.length === 0 ? (
                <p className="alert alert-info">No employees available at the moment.</p>
            ) : (
                <div className="row row-cols-1 row-cols-sm-2 row-cols-lg-3 g-4">
                    {employees.map((employee) => (
                        <EmployeeCard employee={employee} onUpdated={replaceEmployee} key={employee.id}/>
                    ))}
                </div>
            )}
        </section>
    );
}

function EmployeeCard({employee, onUpdated}) {
    const {id, name, jobTitle, profilePictureFilename} = employee;
    const [uploading, setUploading] = useState(false);
    const [error, setError] = useState(null);

    async function handleFileSelected(event) {
        const file = event.target.files[0];
        // Reset the input so choosing the same file again triggers another change event.
        event.target.value = "";
        if (!file) return;

        setUploading(true);
        setError(null);
        try {
            onUpdated(await uploadEmployeePhoto(id, file));
        } catch (uploadError) {
            setError(uploadError.message);
        } finally {
            setUploading(false);
        }
    }

    return (
        <div className="col">
            <div className="card h-100 shadow-sm">
                {profilePictureFilename ? (
                    <img
                        src={employeePhotoUrl(employee)}
                        className="card-img-top"
                        style={{height: "160px", objectFit: "cover"}}
                        alt={`Photo of ${name}`}
                    />
                ) : (
                    <div
                        className="card-img-top d-flex align-items-center justify-content-center bg-light text-secondary"
                        style={{height: "160px"}}
                    >
                        <FontAwesomeIcon icon={faUser} size="3x" title={`No photo of ${name}`}/>
                    </div>
                )}
                <div className="card-body d-flex flex-column">
                    <h5 className="card-title mb-0">{name}</h5>
                    <p className="card-text text-muted small flex-grow-1 mt-2">{jobTitle}</p>
                    {error && <p className="alert alert-danger small py-2 mb-2" role="alert">{error}</p>}
                    <label className={`btn btn-sm btn-outline-primary mt-2 ${uploading ? "disabled" : ""}`}>
                        <FontAwesomeIcon icon={faUpload} className="me-2"/>
                        {uploading ? "Uploading…" : profilePictureFilename ? "Replace photo" : "Upload photo"}
                        <input
                            type="file"
                            className="d-none"
                            accept={acceptedTypes}
                            disabled={uploading}
                            onChange={handleFileSelected}
                            aria-label={`Upload photo for ${name}`}
                        />
                    </label>
                </div>
            </div>
        </div>
    );
}

export default EmployeeList;
