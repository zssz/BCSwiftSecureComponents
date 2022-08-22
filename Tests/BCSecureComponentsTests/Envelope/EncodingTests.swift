import XCTest
import BCSecureComponents
import WolfBase

class EncodingTests: XCTestCase {
    func testDigest() throws {
        try Envelope(Digest("Hello.")).checkEncoding()
    }

    func test1() throws {
        let e = try Envelope(plaintextHello).checkEncoding()
        XCTAssertEqual(e.diagAnnotated,
            """
            200(   ; envelope
               220("Hello.")   ; leaf
            )
            """
        )
    }
    
    func test2() throws {
        let array: CBOR = [1, 2, 3]
        let e = try Envelope(array).checkEncoding()
        XCTAssertEqual(e.diagAnnotated,
            """
            200(   ; envelope
               220(   ; leaf
                  [1, 2, 3]
               )
            )
            """
        )
    }
    
    func test3() throws {
        let e1 = Envelope(predicate: "A", object: "B")
        let e2 = Envelope(predicate: "C", object: "D")
        let e3 = Envelope(predicate: "E", object: "F")
        
        let e4 = try e2.addAssertion(e3)
        XCTAssertEqual(e4.format,
        """
        {
            "C": "D"
        } [
            "E": "F"
        ]
        """
        )
        
        XCTAssertEqual(e4.diagAnnotated,
        """
        200(   ; envelope
           [
              200(   ; envelope
                 221(   ; assertion
                    [
                       200(   ; envelope
                          220("C")   ; leaf
                       ),
                       200(   ; envelope
                          220("D")   ; leaf
                       )
                    ]
                 )
              ),
              200(   ; envelope
                 221(   ; assertion
                    [
                       200(   ; envelope
                          220("E")   ; leaf
                       ),
                       200(   ; envelope
                          220("F")   ; leaf
                       )
                    ]
                 )
              )
           ]
        )
        """)
        
        let e5 = try e1.addAssertion(e4)
        
        XCTAssertEqual(e5.format,
            """
            {
                "A": "B"
            } [
                {
                    "C": "D"
                } [
                    "E": "F"
                ]
            ]
            """
        )

        XCTAssertEqual(e5.diagAnnotated,
            """
            200(   ; envelope
               [
                  200(   ; envelope
                     221(   ; assertion
                        [
                           200(   ; envelope
                              220("A")   ; leaf
                           ),
                           200(   ; envelope
                              220("B")   ; leaf
                           )
                        ]
                     )
                  ),
                  200(   ; envelope
                     [
                        200(   ; envelope
                           221(   ; assertion
                              [
                                 200(   ; envelope
                                    220("C")   ; leaf
                                 ),
                                 200(   ; envelope
                                    220("D")   ; leaf
                                 )
                              ]
                           )
                        ),
                        200(   ; envelope
                           221(   ; assertion
                              [
                                 200(   ; envelope
                                    220("E")   ; leaf
                                 ),
                                 200(   ; envelope
                                    220("F")   ; leaf
                                 )
                              ]
                           )
                        )
                     ]
                  )
               ]
            )
            """
        )
        
        try e5.checkEncoding()
    }
}
