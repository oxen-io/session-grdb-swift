import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct A: TableRecord, FetchableRecord, Decodable, Equatable {
    var cola1: Int64
    var cola2: String
}
private struct B: TableRecord, FetchableRecord, Decodable, Hashable {
    var colb1: Int64
    var colb2: Int64?
    var colb3: String
}
private struct C: TableRecord, FetchableRecord, Decodable, Equatable {
    var colc1: Int64
    var colc2: Int64
}
private struct D: TableRecord, FetchableRecord, Decodable, Equatable {
    var cold1: Int64
    var cold2: Int64
    var cold3: String
}

class AssociationPrefetchingCodableRecordTests: GRDBTestCase {
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("cola1")
                t.column("cola2", .text)
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("colb1")
                t.column("colb2", .integer).references("a")
                t.column("colb3", .text)
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("colc1")
                t.column("colc2", .integer).references("a")
            }
            try db.create(table: "d") { t in
                t.autoIncrementedPrimaryKey("cold1")
                t.column("cold2", .integer).references("c")
                t.column("cold3", .text)
            }
            try db.execute(
                sql: """
                    INSERT INTO a (cola1, cola2) VALUES (?, ?);
                    INSERT INTO a (cola1, cola2) VALUES (?, ?);
                    INSERT INTO a (cola1, cola2) VALUES (?, ?);
                    INSERT INTO b (colb1, colb2, colb3) VALUES (?, ?, ?);
                    INSERT INTO b (colb1, colb2, colb3) VALUES (?, ?, ?);
                    INSERT INTO b (colb1, colb2, colb3) VALUES (?, ?, ?);
                    INSERT INTO b (colb1, colb2, colb3) VALUES (?, ?, ?);
                    INSERT INTO c (colc1, colc2) VALUES (?, ?);
                    INSERT INTO c (colc1, colc2) VALUES (?, ?);
                    INSERT INTO c (colc1, colc2) VALUES (?, ?);
                    INSERT INTO d (cold1, cold2, cold3) VALUES (?, ?, ?);
                    INSERT INTO d (cold1, cold2, cold3) VALUES (?, ?, ?);
                    INSERT INTO d (cold1, cold2, cold3) VALUES (?, ?, ?);
                    INSERT INTO d (cold1, cold2, cold3) VALUES (?, ?, ?);
                    """,
                arguments: [
                    1, "a1",
                    2, "a2",
                    3, "a3",
                    4, 1, "b1",
                    5, 1, "b2",
                    6, 2, "b3",
                    14, nil, "b4",
                    7, 1,
                    8, 2,
                    9, 2,
                    10, 7, "d1",
                    11, 8, "d2",
                    12, 8, "d3",
                    13, 9, "d4",
                ])
        }
    }
    
    func testIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(B.self)
                        .orderByPrimaryKey()
                        .forKey("bs"))  // TODO: auto-pluralization
                    .orderByPrimaryKey()
                
                // Array
                do {
                    struct Record: FetchableRecord, Decodable, Equatable {
                        var a: A
                        var bs: [B]
                    }
                    
                    // Record.fetchAll
                    do {
                        let records = try Record.fetchAll(db, request)
                        XCTAssertEqual(records, [
                            Record(
                                a: A(row: ["cola1": 1, "cola2": "a1"]),
                                bs: [
                                    B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                                    B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                                ]),
                            Record(
                                a: A(row: ["cola1": 2, "cola2": "a2"]),
                                bs: [
                                    B(row: ["colb1": 6, "colb2": 2, "colb3": "b3"]),
                                ]),
                            Record(
                                a: A(row: ["cola1": 3, "cola2": "a3"]),
                                bs: []),
                            ])
                    }
                    
                    // Record.fetchOne
                    do {
                        let record = try Record.fetchOne(db, request)!
                        XCTAssertEqual(record, Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            bs: [
                                B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                                B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                            ]))
                    }
                }
                
                // Set
                do {
                    struct Record: FetchableRecord, Decodable, Equatable {
                        var a: A
                        var bs: Set<B>
                    }
                    
                    // Record.fetchAll
                    do {
                        let records = try Record.fetchAll(db, request)
                        XCTAssertEqual(records, [
                            Record(
                                a: A(row: ["cola1": 1, "cola2": "a1"]),
                                bs: [
                                    B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                                    B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                                ]),
                            Record(
                                a: A(row: ["cola1": 2, "cola2": "a2"]),
                                bs: [
                                    B(row: ["colb1": 6, "colb2": 2, "colb3": "b3"]),
                                ]),
                            Record(
                                a: A(row: ["cola1": 3, "cola2": "a3"]),
                                bs: []),
                            ])
                    }
                    
                    // Record.fetchOne
                    do {
                        let record = try Record.fetchOne(db, request)!
                        XCTAssertEqual(record, Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            bs: [
                                B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                                B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                            ]))
                    }
                }
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(B.self)
                        .filter(Column("colb1") == 4)
                        .orderByPrimaryKey()
                        .forKey("bs1"))
                    .including(all: A
                        .hasMany(B.self)
                        .filter(Column("colb1") != 4)
                        .orderByPrimaryKey()
                        .forKey("bs2"))
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Decodable, Equatable {
                    var a: A
                    var bs1: [B]
                    var bs2: [B]
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    print(records)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            bs1: [
                                B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                            ],
                            bs2: [
                                B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            bs1: [],
                            bs2: [
                                B(row: ["colb1": 6, "colb2": 2, "colb3": "b3"]),
                            ]),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        bs1: [
                            B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                        ],
                        bs2: [
                            B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                        ]))
                }
            }
        }
    }
    
    func testIncludingAllHasManyIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .including(all: C
                            .hasMany(D.self)
                            .orderByPrimaryKey()
                            .forKey("ds"))  // TODO: auto-pluralization
                        .orderByPrimaryKey()
                        .forKey("cs"))  // TODO: auto-pluralization
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Decodable, Equatable {
                    struct CInfo: Decodable, Equatable {
                        var c: C
                        var ds: [D]
                    }
                    var a: A
                    var cs: [CInfo]
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 7, "colc2": 1]),
                                    ds: [
                                        D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                                    ]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 8, "colc2": 2]),
                                    ds: [
                                        D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                        D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                                    ]),
                                Record.CInfo(
                                    c: C(row: ["colc1": 9, "colc2": 2]),
                                    ds: [
                                        D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"]),
                                    ]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 3, "cola2": "a3"]),
                            cs: []),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs: [
                            Record.CInfo(
                                c: C(row: ["colc1": 7, "colc2": 1]),
                                ds: [
                                    D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                                ]),
                        ]))
                }
            }
            
            // Request with avoided prefetch
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .filter(false)
                        .including(all: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                        .orderByPrimaryKey()
                        .forKey("cs"))  // TODO: auto-pluralization
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Decodable, Equatable {
                    struct CInfo: Decodable, Equatable {
                        var c: C
                        var ds: [D]
                    }
                    var a: A
                    var cs: [CInfo]
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs: []),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs: []),
                        Record(
                            a: A(row: ["cola1": 3, "cola2": "a3"]),
                            cs: []),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs: []))
                }
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") > 7)
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("ds1"))
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("ds2"))
                        .orderByPrimaryKey()
                        .forKey("cs1"))
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") < 9)
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("ds1"))
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("ds2"))
                        .orderByPrimaryKey()
                        .forKey("cs2"))
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Decodable, Equatable {
                    struct CInfo: Decodable, Equatable {
                        var c: C
                        var ds1: [D]
                        var ds2: [D]
                    }
                    var a: A
                    var cs1: [CInfo]
                    var cs2: [CInfo]
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs1: [],
                            cs2: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 7, "colc2": 1]),
                                    ds1: [],
                                    ds2: [
                                        D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                                    ]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs1: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 8, "colc2": 2]),
                                    ds1: [
                                        D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                    ],
                                    ds2: [
                                        D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                                    ]),
                                Record.CInfo(
                                    c: C(row: ["colc1": 9, "colc2": 2]),
                                    ds1: [],
                                    ds2: [
                                        D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"]),
                                    ]),
                            ],
                            cs2: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 8, "colc2": 2]),
                                    ds1: [
                                        D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                    ],
                                    ds2: [
                                        D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                                    ]),
                            ]),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs1: [],
                        cs2: [
                            Record.CInfo(
                                c: C(row: ["colc1": 7, "colc2": 1]),
                                ds1: [],
                                ds2: [
                                    D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                                ]),
                        ]))
                }
            }
        }
    }
    
    func testIncludingAllHasManyIncludingRequiredOrOptionalHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .including(required: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                        .orderByPrimaryKey()
                        .forKey("cs"))  // TODO: auto-pluralization
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Decodable, Equatable {
                    struct CInfo: Decodable, Equatable {
                        var c: C
                        var d: D
                    }
                    var a: A
                    var cs: [CInfo]
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 7, "colc2": 1]),
                                    d: D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"])),
                            ]),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 8, "colc2": 2]),
                                    d: D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"])),
                                Record.CInfo(
                                    c: C(row: ["colc1": 8, "colc2": 2]),
                                    d: D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"])),
                                Record.CInfo(
                                    c: C(row: ["colc1": 9, "colc2": 2]),
                                    d: D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"])),
                            ]),
                        Record(
                            a: A(row: ["cola1": 3, "cola2": "a3"]),
                            cs: []),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs: [
                            Record.CInfo(
                                c: C(row: ["colc1": 7, "colc2": 1]),
                                d: D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"])),
                        ]))
                }
            }
            
            // Request with avoided prefetch
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .filter(false)
                        .including(required: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                        .orderByPrimaryKey()
                        .forKey("cs"))  // TODO: auto-pluralization
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Decodable, Equatable {
                    struct CInfo: Decodable, Equatable {
                        var c: C
                        var d: D
                    }
                    var a: A
                    var cs: [CInfo]
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs: []),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs: []),
                        Record(
                            a: A(row: ["cola1": 3, "cola2": "a3"]),
                            cs: []),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs: []))
                }
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") > 7)
                        .including(optional: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("d1"))
                        .including(required: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("d2"))
                        .orderByPrimaryKey()
                        .forKey("cs1"))
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") < 9)
                        .including(optional: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("d1"))
                        .including(required: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("d2"))
                        .orderByPrimaryKey()
                        .forKey("cs2"))
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Decodable, Equatable {
                    struct CInfo: Decodable, Equatable {
                        var c: C
                        var d1: D?
                        var d2: D
                    }
                    var a: A
                    var cs1: [CInfo]
                    var cs2: [CInfo]
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs1: [],
                            cs2: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 7, "colc2": 1]),
                                    d1: nil,
                                    d2: D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"])),
                            ]),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs1: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 8, "colc2": 2]),
                                    d1: D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                    d2: D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"])),
                                Record.CInfo(
                                    c: C(row: ["colc1": 9, "colc2": 2]),
                                    d1: nil,
                                    d2: D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"])),
                            ],
                            cs2: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 8, "colc2": 2]),
                                    d1: D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                    d2: D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"])),
                            ]),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs1: [],
                        cs2: [
                            Record.CInfo(
                                c: C(row: ["colc1": 7, "colc2": 1]),
                                d1: nil,
                                d2: D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"])),
                        ]))
                }
            }
        }
    }
    
    func testIncludingAllHasManyThrough() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self), using: C.hasMany(D.self))
                        .orderByPrimaryKey()
                        .forKey("ds"))  // TODO: auto-pluralization
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Decodable, Equatable {
                    var a: A
                    var ds: [D]
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            ds: [
                                D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            ds: [
                                D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                                D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 3, "cola2": "a3"]),
                            ds: []),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        ds: [
                            D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                        ]))
                }
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self).filter(Column("colc1") == 8), using: C.hasMany(D.self))
                        .orderByPrimaryKey()
                        .forKey("ds1"))
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self), using: C.hasMany(D.self))
                        .filter(Column("cold1") != 11)
                        .orderByPrimaryKey()
                        .forKey("ds2"))
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self), using: C.hasMany(D.self))
                        .filter(Column("cold1") == 11)
                        .orderByPrimaryKey()
                        .forKey("ds3"))
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Decodable, Equatable {
                    var a: A
                    var ds1: [D]
                    var ds2: [D]
                    var ds3: [D]
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            ds1: [],
                            ds2: [
                                D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                            ],
                            ds3: []),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            ds1: [
                                D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                            ],
                            ds2: [
                                D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                                D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"]),
                            ],
                            ds3: [
                                D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                            ]),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        ds1: [],
                        ds2: [
                            D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                        ],
                        ds3: []))
                }
            }
        }
    }
    
    func testIncludingAllHasManyThroughIsNotMergedWithHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let cs = A.hasMany(C.self).forKey("cs")
                let request = A
                    .including(all: cs.orderByPrimaryKey())
                    .including(all: A
                        .hasMany(D.self, through: cs, using: C.hasMany(D.self))
                        .orderByPrimaryKey()
                        .forKey("ds"))  // TODO: auto-pluralization
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Decodable, Equatable {
                    var a: A
                    var cs: [C]
                    var ds: [D]
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs: [
                                C(row: ["colc1": 7, "colc2": 1]),
                            ],
                            ds: [
                                D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs: [
                                C(row: ["colc1": 8, "colc2": 2]),
                                C(row: ["colc1": 9, "colc2": 2]),
                            ],
                            ds: [
                                D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                                D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 3, "cola2": "a3"]),
                            cs: [],
                            ds: []),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs: [
                            C(row: ["colc1": 7, "colc2": 1]),
                        ],
                        ds: [
                            D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                        ]))
                }
            }
            
            // Request with filters
            do {
                let cs1 = A.hasMany(C.self).forKey("cs1")
                let cs2 = A.hasMany(C.self).forKey("cs2")
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: cs1
                        .filter(Column("colc1") != 8)
                        .orderByPrimaryKey())
                    .including(all: A
                        .hasMany(D.self, through: cs1, using: C.hasMany(D.self))
                        .filter(Column("cold1") != 11)
                        .orderByPrimaryKey()
                        .forKey("ds1"))
                    .including(all: cs2
                        .filter(Column("colc1") != 9)
                        .orderByPrimaryKey())
                    .including(all: A
                        .hasMany(D.self, through: cs2, using: C.hasMany(D.self))
                        .filter(Column("cold1") == 11)
                        .orderByPrimaryKey()
                        .forKey("ds2"))
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Decodable, Equatable {
                    var a: A
                    var cs1: [C]
                    var cs2: [C]
                    var ds1: [D]
                    var ds2: [D]
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs1: [
                                C(row: ["colc1": 7, "colc2": 1]),
                            ],
                            cs2: [
                                C(row: ["colc1": 7, "colc2": 1]),
                            ],
                            ds1: [
                                D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                            ],
                            ds2: []),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs1: [
                                C(row: ["colc1": 9, "colc2": 2]),
                            ],
                            cs2: [
                                C(row: ["colc1": 8, "colc2": 2]),
                            ],
                            ds1: [
                                D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                                D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"]),
                            ],
                            ds2: [
                                D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                            ]),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs1: [
                            C(row: ["colc1": 7, "colc2": 1]),
                        ],
                        cs2: [
                            C(row: ["colc1": 7, "colc2": 1]),
                        ],
                        ds1: [
                            D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                        ],
                        ds2: []))
                }
            }
        }
    }
    
    // TODO: make a variant with joining(optional:)
    func testIncludingOptionalBelongsToIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = B
                    .including(optional: B
                        .belongsTo(A.self)
                        .including(all: A
                            .hasMany(C.self)
                            .orderByPrimaryKey()
                            .forKey("cs"))  // TODO: auto-pluralization
                    )
                    .orderByPrimaryKey()
                
                // Record (nested)
                do {
                    struct Record: FetchableRecord, Decodable, Equatable {
                        struct AInfo: Decodable, Equatable {
                            var a: A
                            var cs: [C]
                        }
                        var b: B
                        var a: AInfo?
                    }
                    
                    // Record.fetchAll
                    do {
                        let records = try Record.fetchAll(db, request)
                        XCTAssertEqual(records, [
                            Record(
                                b: B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                                a: Record.AInfo(
                                    a: A(row: ["cola1": 1, "cola2": "a1"]),
                                    cs: [
                                        C(row: ["colc1": 7, "colc2": 1]),
                                    ])),
                            Record(
                                b: B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                                a: Record.AInfo(
                                    a: A(row: ["cola1": 1, "cola2": "a1"]),
                                    cs: [
                                        C(row: ["colc1": 7, "colc2": 1]),
                                    ])),
                            Record(
                                b: B(row: ["colb1": 6, "colb2": 2, "colb3": "b3"]),
                                a: Record.AInfo(
                                    a: A(row: ["cola1": 2, "cola2": "a2"]),
                                    cs: [
                                        C(row: ["colc1": 8, "colc2": 2]),
                                        C(row: ["colc1": 9, "colc2": 2]),
                                    ])),
                            Record(
                                b: B(row: ["colb1": 14, "colb2": nil, "colb3": "b4"]),
                                a: nil),
                            ])
                    }
                    
                    // Record.fetchOne
                    do {
                        let record = try Record.fetchOne(db, request)!
                        XCTAssertEqual(record, Record(
                            b: B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                            a: Record.AInfo(
                                a: A(row: ["cola1": 1, "cola2": "a1"]),
                                cs: [
                                    C(row: ["colc1": 7, "colc2": 1]),
                                ])))
                    }
                }
                
                // Record (flat)
                do {
                    struct Record: FetchableRecord, Decodable, Equatable {
                        var b: B
                        var a: A?
                        var cs: [C] // not optional
                    }
                    
                    // Record.fetchAll
                    do {
                        let records = try Record.fetchAll(db, request)
                        XCTAssertEqual(records, [
                            Record(
                                b: B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                                a: A(row: ["cola1": 1, "cola2": "a1"]),
                                cs: [
                                    C(row: ["colc1": 7, "colc2": 1]),
                                ]),
                            Record(
                                b: B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                                a: A(row: ["cola1": 1, "cola2": "a1"]),
                                cs: [
                                    C(row: ["colc1": 7, "colc2": 1]),
                                ]),
                            Record(
                                b: B(row: ["colb1": 6, "colb2": 2, "colb3": "b3"]),
                                a: A(row: ["cola1": 2, "cola2": "a2"]),
                                cs: [
                                    C(row: ["colc1": 8, "colc2": 2]),
                                    C(row: ["colc1": 9, "colc2": 2]),
                                ]),
                            Record(
                                b: B(row: ["colb1": 14, "colb2": nil, "colb3": "b4"]),
                                a: nil,
                                cs: []),
                            ])
                    }
                    
                    // Record.fetchOne
                    do {
                        let record = try Record.fetchOne(db, request)!
                        XCTAssertEqual(record, Record(
                            b: B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs: [
                                C(row: ["colc1": 7, "colc2": 1]),
                            ]))
                    }
                }
            }
            
            // Request with filters
            do {
                let request = B
                    .including(optional: B
                        .belongsTo(A.self)
                        .filter(Column("cola2") == "a1")
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") == 9)
                            .orderByPrimaryKey()
                            .forKey("cs1"))
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") != 9)
                            .orderByPrimaryKey()
                            .forKey("cs2"))
                        .forKey("a1"))
                    .including(optional: B
                        .belongsTo(A.self)
                        .filter(Column("cola2") == "a2")
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") == 9)
                            .orderByPrimaryKey()
                            .forKey("cs1"))
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") != 9)
                            .orderByPrimaryKey()
                            .forKey("cs2"))
                        .forKey("a2"))
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Decodable, Equatable {
                    struct AInfo: Decodable, Equatable {
                        var a: A
                        var cs1: [C]
                        var cs2: [C]
                    }
                    var b: B
                    var a1: AInfo?
                    var a2: AInfo?
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            b: B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                            a1: Record.AInfo(
                                a: A(row: ["cola1": 1, "cola2": "a1"]),
                                cs1: [],
                                cs2: [
                                    C(row: ["colc1": 7, "colc2": 1]),
                                ]),
                            a2: nil),
                        Record(
                            b: B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                            a1: Record.AInfo(
                                a: A(row: ["cola1": 1, "cola2": "a1"]),
                                cs1: [],
                                cs2: [
                                    C(row: ["colc1": 7, "colc2": 1]),
                                ]),
                            a2: nil),
                        Record(
                            b: B(row: ["colb1": 6, "colb2": 2, "colb3": "b3"]),
                            a1: nil,
                            a2: Record.AInfo(
                                a: A(row: ["cola1": 2, "cola2": "a2"]),
                                cs1: [
                                    C(row: ["colc1": 9, "colc2": 2]),
                                ],
                                cs2: [
                                    C(row: ["colc1": 8, "colc2": 2]),
                                ])),
                        Record(
                            b: B(row: ["colb1": 14, "colb2": nil, "colb3": "b4"]),
                            a1: nil,
                            a2: nil),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        b: B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                        a1: Record.AInfo(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs1: [],
                            cs2: [
                                C(row: ["colc1": 7, "colc2": 1]),
                            ]),
                        a2: nil))
                }
            }
        }
    }
}
