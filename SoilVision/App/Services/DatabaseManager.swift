import Foundation
import SQLite3
import Combine

class DatabaseManager: ObservableObject {
    @Published var soilResults: [SoilResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var db: OpaquePointer?
    private let dbPath: String

    init() {
        // Get path to the documents directory
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("SoilVisionDatabase.sqlite")

        dbPath = fileURL.path
    }

    func setupDatabase() {
        // Open database connection
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            print("Database opened successfully")
            createTables()
            loadLocalResults()
        } else {
            print("Unable to open database")
            errorMessage = "Database initialization failed"
        }
    }

    private func createTables() {
        // Create soil_tests table
        let createSoilTestsTableSQL = """
            CREATE TABLE IF NOT EXISTS soil_tests (
                id TEXT PRIMARY KEY,
                user_id TEXT,
                image_local_path TEXT NOT NULL,
                image_url TEXT,
                classification_result TEXT NOT NULL,
                confidence_score REAL NOT NULL,
                gps_latitude REAL,
                gps_longitude REAL,
                gps_accuracy REAL,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                synced BOOLEAN DEFAULT FALSE,
                location_data TEXT,
                metadata TEXT
            );
        """

        if sqlite3_exec(db, createSoilTestsTableSQL, nil, nil, nil) == SQLITE_OK {
            print("soil_tests table created successfully")
        } else {
            print("Error creating soil_tests table")
        }

        // Create users table
        let createUsersTableSQL = """
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                email TEXT UNIQUE NOT NULL,
                location TEXT,
                profile_image_url TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                preferences TEXT,
                statistics TEXT
            );
        """

        if sqlite3_exec(db, createUsersTableSQL, nil, nil, nil) == SQLITE_OK {
            print("users table created successfully")
        } else {
            print("Error creating users table")
        }
    }

    func saveSoilResult(_ result: SoilResult) {
        isLoading = true
        errorMessage = nil

        let insertSQL = """
            INSERT INTO soil_tests (
                id, user_id, image_local_path, image_url,
                classification_result, confidence_score,
                gps_latitude, gps_longitude, gps_accuracy,
                timestamp, synced, location_data, metadata
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            // Bind parameters
            sqlite3_bind_text(statement, 1, result.id, -1, nil)
            sqlite3_bind_text(statement, 2, result.userId, -1, nil)
            sqlite3_bind_text(statement, 3, result.imageLocalPath, -1, nil)
            sqlite3_bind_text(statement, 4, result.imageURL, -1, nil)
            sqlite3_bind_text(statement, 5, result.classificationResult.rawValue, -1, nil)
            sqlite3_bind_double(statement, 6, result.confidenceScore)

            if let location = result.location {
                sqlite3_bind_double(statement, 7, location.latitude)
                sqlite3_bind_double(statement, 8, location.longitude)
                sqlite3_bind_double(statement, 9, location.accuracy)
            } else {
                sqlite3_bind_null(statement, 7)
                sqlite3_bind_null(statement, 8)
                sqlite3_bind_null(statement, 9)
            }

            sqlite3_bind_double(statement, 10, result.timestamp.timeIntervalSince1970)
            sqlite3_bind_int(statement, 11, result.synced ? 1 : 0)

            // Encode location data as JSON
            if let locationData = try? JSONEncoder().encode(result.location),
               let locationString = String(data: locationData, encoding: .utf8) {
                sqlite3_bind_text(statement, 12, locationString, -1, nil)
            } else {
                sqlite3_bind_null(statement, 12)
            }

            // Encode metadata as JSON
            if let metadataData = try? JSONEncoder().encode(result.metadata),
               let metadataString = String(data: metadataData, encoding: .utf8) {
                sqlite3_bind_text(statement, 13, metadataString, -1, nil)
            } else {
                sqlite3_bind_null(statement, 13)
            }

            // Execute
            if sqlite3_step(statement) == SQLITE_DONE {
                print("Soil result saved successfully")
                loadLocalResults() // Refresh the results
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("Error saving soil result: \(errorMessage)")
                self.errorMessage = "Failed to save result"
            }
        }

        sqlite3_finalize(statement)
        isLoading = false
    }

    func loadLocalResults() {
        soilResults.removeAll()

        let querySQL = "SELECT * FROM soil_tests ORDER BY timestamp DESC;"

        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let result = createSoilResultFromStatement(statement) {
                    soilResults.append(result)
                }
            }
        }

        sqlite3_finalize(statement)
        print("Loaded \(soilResults.count) soil results from local database")
    }

    private func createSoilResultFromStatement(_ statement: OpaquePointer?) -> SoilResult? {
        guard let statement = statement else { return nil }

        // Extract values from the row
        let id = String(cString: sqlite3_column_text(statement, 0))
        let userId = sqlite3_column_text(statement, 1) != nil ? String(cString: sqlite3_column_text(statement, 1)) : nil
        let imageLocalPath = String(cString: sqlite3_column_text(statement, 2))
        let imageURL = sqlite3_column_text(statement, 3) != nil ? String(cString: sqlite3_column_text(statement, 3)) : nil
        let classificationResultString = String(cString: sqlite3_column_text(statement, 4))
        let confidenceScore = sqlite3_column_double(statement, 5)

        // Extract location data
        var location: LocationData?
        if let locationDataString = sqlite3_column_text(statement, 12) {
            let locationDataString = String(cString: locationDataString)
            if let locationData = locationDataString.data(using: .utf8) {
                location = try? JSONDecoder().decode(LocationData.self, from: locationData)
            }
        }

        // Extract metadata
        var metadata: SoilTestMetadata?
        if let metadataString = sqlite3_column_text(statement, 13) {
            let metadataString = String(cString: metadataString)
            if let metadataData = metadataString.data(using: .utf8) {
                metadata = try? JSONDecoder().decode(SoilTestMetadata.self, from: metadataData)
            }
        }

        let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 9))
        let synced = sqlite3_column_int(statement, 10) == 1

        // Convert soil type string to enum
        guard let soilType = SoilType(rawValue: classificationResultString) else {
            print("Unknown soil type: \(classificationResultString)")
            return nil
        }

        // Create SoilResult object
        var result = SoilResult(
            id: id,
            userId: userId,
            imageLocalPath: imageLocalPath,
            classificationResult: soilType,
            confidenceScore: confidenceScore,
            location: location,
            metadata: metadata ?? SoilTestMetadata()
        )

        result.imageURL = imageURL
        result.synced = synced

        return result
    }

    func deleteSoilResult(_ result: SoilResult) {
        let deleteSQL = "DELETE FROM soil_tests WHERE id = ?;"

        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, result.id, -1, nil)

            if sqlite3_step(statement) == SQLITE_DONE {
                print("Soil result deleted successfully")
                loadLocalResults() // Refresh the results
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("Error deleting soil result: \(errorMessage)")
                self.errorMessage = "Failed to delete result"
            }
        }

        sqlite3_finalize(statement)
    }

    func updateSoilResult(_ result: SoilResult) {
        let updateSQL = """
            UPDATE soil_tests SET
                image_url = ?,
                synced = ?,
                location_data = ?,
                metadata = ?
            WHERE id = ?;
        """

        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            // Bind parameters
            sqlite3_bind_text(statement, 1, result.imageURL, -1, nil)
            sqlite3_bind_int(statement, 2, result.synced ? 1 : 0)

            // Encode location data as JSON
            if let locationData = try? JSONEncoder().encode(result.location),
               let locationString = String(data: locationData, encoding: .utf8) {
                sqlite3_bind_text(statement, 3, locationString, -1, nil)
            } else {
                sqlite3_bind_null(statement, 3)
            }

            // Encode metadata as JSON
            if let metadataData = try? JSONEncoder().encode(result.metadata),
               let metadataString = String(data: metadataData, encoding: .utf8) {
                sqlite3_bind_text(statement, 4, metadataString, -1, nil)
            } else {
                sqlite3_bind_null(statement, 4)
            }

            sqlite3_bind_text(statement, 5, result.id, -1, nil)

            // Execute
            if sqlite3_step(statement) == SQLITE_DONE {
                print("Soil result updated successfully")
                loadLocalResults() // Refresh the results
            } else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("Error updating soil result: \(errorMessage)")
                self.errorMessage = "Failed to update result"
            }
        }

        sqlite3_finalize(statement)
    }

    func clearError() {
        errorMessage = nil
    }

    deinit {
        sqlite3_close(db)
    }
}