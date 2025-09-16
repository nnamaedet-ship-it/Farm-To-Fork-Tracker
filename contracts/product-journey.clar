;; Product Journey Smart Contract
;; Tracks products from farm through processing to consumer for complete supply chain visibility

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u2001))
(define-constant ERR_PRODUCT_NOT_FOUND (err u2002))
(define-constant ERR_BATCH_NOT_FOUND (err u2003))
(define-constant ERR_INVALID_PRODUCT_DATA (err u2004))
(define-constant ERR_INVALID_BATCH_DATA (err u2005))
(define-constant ERR_JOURNEY_STEP_NOT_FOUND (err u2006))
(define-constant ERR_INVALID_JOURNEY_DATA (err u2007))
(define-constant ERR_PRODUCT_ALREADY_SHIPPED (err u2008))
(define-constant ERR_INVALID_HANDLER (err u2009))
(define-constant ERR_INVALID_PARAMETERS (err u2010))
(define-constant ERR_BATCH_ALREADY_EXISTS (err u2011))
(define-constant ERR_INVALID_LOCATION (err u2012))
(define-constant ERR_HANDLER_NOT_AUTHORIZED (err u2013))

;; Product status constants
(define-constant PRODUCT_STATUS_HARVESTED u1)
(define-constant PRODUCT_STATUS_IN_TRANSIT u2)
(define-constant PRODUCT_STATUS_PROCESSING u3)
(define-constant PRODUCT_STATUS_PACKAGED u4)
(define-constant PRODUCT_STATUS_SHIPPED u5)
(define-constant PRODUCT_STATUS_DELIVERED u6)
(define-constant PRODUCT_STATUS_SOLD u7)
(define-constant PRODUCT_STATUS_RECALLED u8)

;; Journey step types
(define-constant STEP_TYPE_HARVEST u1)
(define-constant STEP_TYPE_TRANSPORT u2)
(define-constant STEP_TYPE_PROCESSING u3)
(define-constant STEP_TYPE_PACKAGING u4)
(define-constant STEP_TYPE_QUALITY_CHECK u5)
(define-constant STEP_TYPE_STORAGE u6)
(define-constant STEP_TYPE_RETAIL u7)

;; Contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Data structures
;; Product batch information
(define-map product-batches
    { batch-id: (string-ascii 50) }
    {
        farm-id: uint,
        product-type: (string-ascii 100),
        variety: (string-ascii 100),
        harvest-date: uint,
        quantity-kg: uint,
        origin-location: (string-ascii 200),
        organic-certified: bool,
        batch-owner: principal,
        current-status: uint,
        current-location: (string-ascii 200),
        current-handler: principal,
        creation-timestamp: uint,
        last-updated: uint,
        temperature-controlled: bool,
        expiry-date: uint
    }
)

;; Journey steps for tracking movement
(define-map journey-steps
    { batch-id: (string-ascii 50), step-id: uint }
    {
        step-type: uint,
        timestamp: uint,
        handler: principal,
        location: (string-ascii 200),
        description: (string-ascii 500),
        temperature-celsius: (optional int),
        humidity-percent: (optional uint),
        duration-hours: uint,
        notes: (string-ascii 1000),
        verification-hash: (buff 32),
        next-handler: (optional principal)
    }
)

;; Product processing records
(define-map processing-records
    { batch-id: (string-ascii 50), process-id: uint }
    {
        process-type: (string-ascii 100),
        processor: principal,
        start-timestamp: uint,
        end-timestamp: uint,
        input-quantity-kg: uint,
        output-quantity-kg: uint,
        processing-location: (string-ascii 200),
        quality-grade: (string-ascii 20),
        additives-used: (list 10 (string-ascii 100)),
        certification-maintained: bool,
        waste-generated-kg: uint
    }
)

;; Logistics tracking
(define-map logistics-records
    { batch-id: (string-ascii 50), logistics-id: uint }
    {
        transport-type: (string-ascii 50),
        carrier: principal,
        departure-location: (string-ascii 200),
        destination-location: (string-ascii 200),
        departure-time: uint,
        arrival-time: (optional uint),
        vehicle-id: (string-ascii 50),
        driver-id: (string-ascii 50),
        temperature-maintained: bool,
        tracking-number: (string-ascii 100),
        estimated-delivery: uint
    }
)

;; Package information
(define-map package-details
    { batch-id: (string-ascii 50) }
    {
        package-type: (string-ascii 100),
        package-size: (string-ascii 50),
        package-weight-kg: uint,
        packaging-date: uint,
        packaging-location: (string-ascii 200),
        packager: principal,
        package-materials: (list 5 (string-ascii 100)),
        recyclable: bool,
        labeling-info: (string-ascii 500),
        barcode: (string-ascii 100)
    }
)

;; Counters for unique IDs
(define-data-var step-counter uint u0)
(define-data-var process-counter uint u0)
(define-data-var logistics-counter uint u0)

;; Authorized handlers (processors, transporters, retailers)
(define-map authorized-handlers 
    { handler: principal } 
    { 
        authorized: bool, 
        handler-type: (string-ascii 50),
        certification: (string-ascii 100),
        location: (string-ascii 200)
    }
)

;; Admin functions
;; Authorize a handler
(define-public (authorize-handler 
    (handler principal) 
    (handler-type (string-ascii 50))
    (certification (string-ascii 100))
    (location (string-ascii 200))
)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (ok (map-set authorized-handlers 
            { handler: handler } 
            { 
                authorized: true, 
                handler-type: handler-type,
                certification: certification,
                location: location
            }
        ))
    )
)

;; Revoke handler authorization
(define-public (revoke-handler (handler principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (ok (map-delete authorized-handlers { handler: handler }))
    )
)

;; Core product journey functions
;; Create new product batch
(define-public (create-product-batch
    (batch-id (string-ascii 50))
    (farm-id uint)
    (product-type (string-ascii 100))
    (variety (string-ascii 100))
    (harvest-date uint)
    (quantity-kg uint)
    (origin-location (string-ascii 200))
    (organic-certified bool)
    (temperature-controlled bool)
    (expiry-date uint)
)
    (let 
        (
            (current-time stacks-block-height)
        )
        (begin
            ;; Validate input parameters
            (asserts! (> (len batch-id) u0) ERR_INVALID_PARAMETERS)
            (asserts! (> (len product-type) u0) ERR_INVALID_PARAMETERS)
            (asserts! (> quantity-kg u0) ERR_INVALID_PARAMETERS)
            (asserts! (< harvest-date expiry-date) ERR_INVALID_PARAMETERS)
            
            ;; Check if batch already exists
            (asserts! (is-none (map-get? product-batches { batch-id: batch-id })) ERR_BATCH_ALREADY_EXISTS)
            
            ;; Create product batch
            (map-set product-batches
                { batch-id: batch-id }
                {
                    farm-id: farm-id,
                    product-type: product-type,
                    variety: variety,
                    harvest-date: harvest-date,
                    quantity-kg: quantity-kg,
                    origin-location: origin-location,
                    organic-certified: organic-certified,
                    batch-owner: tx-sender,
                    current-status: PRODUCT_STATUS_HARVESTED,
                    current-location: origin-location,
                    current-handler: tx-sender,
                    creation-timestamp: current-time,
                    last-updated: current-time,
                    temperature-controlled: temperature-controlled,
                    expiry-date: expiry-date
                }
            )
            
            ;; Create initial journey step
            (unwrap! (add-journey-step
                batch-id
                STEP_TYPE_HARVEST
                origin-location
                "Initial harvest and batch creation"
                none
                none
                u0
                "Product harvested and batch created"
                0x00000000000000000000000000000000
                none
            ) ERR_INVALID_JOURNEY_DATA)
            
            (ok batch-id)
        )
    )
)

;; Add journey step
(define-public (add-journey-step
    (batch-id (string-ascii 50))
    (step-type uint)
    (location (string-ascii 200))
    (description (string-ascii 500))
    (temperature-celsius (optional int))
    (humidity-percent (optional uint))
    (duration-hours uint)
    (notes (string-ascii 1000))
    (verification-hash (buff 32))
    (next-handler (optional principal))
)
    (let 
        (
            (batch-data (unwrap! (map-get? product-batches { batch-id: batch-id }) ERR_BATCH_NOT_FOUND))
            (new-step-id (+ (var-get step-counter) u1))
            (current-time stacks-block-height)
        )
        (begin
            ;; Check if caller is current handler or authorized
            (asserts! (or 
                (is-eq tx-sender (get current-handler batch-data))
                (is-eq tx-sender CONTRACT_OWNER)
                (default-to false (get authorized (map-get? authorized-handlers { handler: tx-sender })))
            ) ERR_UNAUTHORIZED)
            
            ;; Validate parameters
            (asserts! (> (len location) u0) ERR_INVALID_LOCATION)
            (asserts! (> (len description) u0) ERR_INVALID_JOURNEY_DATA)
            
            ;; Add journey step
            (map-set journey-steps
                { batch-id: batch-id, step-id: new-step-id }
                {
                    step-type: step-type,
                    timestamp: current-time,
                    handler: tx-sender,
                    location: location,
                    description: description,
                    temperature-celsius: temperature-celsius,
                    humidity-percent: humidity-percent,
                    duration-hours: duration-hours,
                    notes: notes,
                    verification-hash: verification-hash,
                    next-handler: next-handler
                }
            )
            
            ;; Update batch location and handler if next handler specified
            (map-set product-batches
                { batch-id: batch-id }
                (merge batch-data {
                    current-location: location,
                    current-handler: (default-to (get current-handler batch-data) next-handler),
                    last-updated: current-time
                })
            )
            
            ;; Update counter
            (var-set step-counter new-step-id)
            
            (ok new-step-id)
        )
    )
)

;; Update product status
(define-public (update-product-status
    (batch-id (string-ascii 50))
    (new-status uint)
    (location (string-ascii 200))
    (notes (string-ascii 500))
)
    (let 
        (
            (batch-data (unwrap! (map-get? product-batches { batch-id: batch-id }) ERR_BATCH_NOT_FOUND))
            (current-time stacks-block-height)
        )
        (begin
            ;; Check authorization
            (asserts! (or 
                (is-eq tx-sender (get current-handler batch-data))
                (is-eq tx-sender CONTRACT_OWNER)
                (default-to false (get authorized (map-get? authorized-handlers { handler: tx-sender })))
            ) ERR_UNAUTHORIZED)
            
            ;; Validate status
            (asserts! (and (>= new-status u1) (<= new-status u8)) ERR_INVALID_PARAMETERS)
            
            ;; Update batch status
            (map-set product-batches
                { batch-id: batch-id }
                (merge batch-data {
                    current-status: new-status,
                    current-location: location,
                    last-updated: current-time
                })
            )
            
            ;; Add journey step for status change
            (unwrap! (add-journey-step
                batch-id
                (if (is-eq new-status PRODUCT_STATUS_PROCESSING) STEP_TYPE_PROCESSING
                    (if (is-eq new-status PRODUCT_STATUS_PACKAGED) STEP_TYPE_PACKAGING
                        (if (is-eq new-status PRODUCT_STATUS_SHIPPED) STEP_TYPE_TRANSPORT
                            STEP_TYPE_STORAGE
                        )
                    )
                )
                location
"Status updated"
                none
                none
                u0
                notes
                0x00000000000000000000000000000000
                none
            ) ERR_INVALID_JOURNEY_DATA)
            
            (ok true)
        )
    )
)

;; Record processing activity
(define-public (record-processing
    (batch-id (string-ascii 50))
    (process-type (string-ascii 100))
    (start-timestamp uint)
    (end-timestamp uint)
    (input-quantity-kg uint)
    (output-quantity-kg uint)
    (processing-location (string-ascii 200))
    (quality-grade (string-ascii 20))
    (additives-used (list 10 (string-ascii 100)))
    (certification-maintained bool)
    (waste-generated-kg uint)
)
    (let 
        (
            (batch-data (unwrap! (map-get? product-batches { batch-id: batch-id }) ERR_BATCH_NOT_FOUND))
            (new-process-id (+ (var-get process-counter) u1))
        )
        (begin
            ;; Check authorization
            (asserts! (or 
                (is-eq tx-sender (get current-handler batch-data))
                (is-eq tx-sender CONTRACT_OWNER)
                (default-to false (get authorized (map-get? authorized-handlers { handler: tx-sender })))
            ) ERR_UNAUTHORIZED)
            
            ;; Validate processing data
            (asserts! (< start-timestamp end-timestamp) ERR_INVALID_PARAMETERS)
            (asserts! (> input-quantity-kg u0) ERR_INVALID_PARAMETERS)
            
            ;; Record processing
            (map-set processing-records
                { batch-id: batch-id, process-id: new-process-id }
                {
                    process-type: process-type,
                    processor: tx-sender,
                    start-timestamp: start-timestamp,
                    end-timestamp: end-timestamp,
                    input-quantity-kg: input-quantity-kg,
                    output-quantity-kg: output-quantity-kg,
                    processing-location: processing-location,
                    quality-grade: quality-grade,
                    additives-used: additives-used,
                    certification-maintained: certification-maintained,
                    waste-generated-kg: waste-generated-kg
                }
            )
            
            ;; Update batch quantity
            (map-set product-batches
                { batch-id: batch-id }
                (merge batch-data {
                    quantity-kg: output-quantity-kg,
                    current-status: PRODUCT_STATUS_PROCESSING,
                    current-location: processing-location,
                    last-updated: stacks-block-height
                })
            )
            
            ;; Update counter
            (var-set process-counter new-process-id)
            
            (ok new-process-id)
        )
    )
)

;; Record logistics information
(define-public (record-logistics
    (batch-id (string-ascii 50))
    (transport-type (string-ascii 50))
    (departure-location (string-ascii 200))
    (destination-location (string-ascii 200))
    (departure-time uint)
    (vehicle-id (string-ascii 50))
    (driver-id (string-ascii 50))
    (temperature-maintained bool)
    (tracking-number (string-ascii 100))
    (estimated-delivery uint)
)
    (let 
        (
            (batch-data (unwrap! (map-get? product-batches { batch-id: batch-id }) ERR_BATCH_NOT_FOUND))
            (new-logistics-id (+ (var-get logistics-counter) u1))
        )
        (begin
            ;; Check authorization
            (asserts! (or 
                (is-eq tx-sender (get current-handler batch-data))
                (is-eq tx-sender CONTRACT_OWNER)
                (default-to false (get authorized (map-get? authorized-handlers { handler: tx-sender })))
            ) ERR_UNAUTHORIZED)
            
            ;; Record logistics
            (map-set logistics-records
                { batch-id: batch-id, logistics-id: new-logistics-id }
                {
                    transport-type: transport-type,
                    carrier: tx-sender,
                    departure-location: departure-location,
                    destination-location: destination-location,
                    departure-time: departure-time,
                    arrival-time: none,
                    vehicle-id: vehicle-id,
                    driver-id: driver-id,
                    temperature-maintained: temperature-maintained,
                    tracking-number: tracking-number,
                    estimated-delivery: estimated-delivery
                }
            )
            
            ;; Update batch status
            (map-set product-batches
                { batch-id: batch-id }
                (merge batch-data {
                    current-status: PRODUCT_STATUS_IN_TRANSIT,
                    current-location: departure-location,
                    last-updated: stacks-block-height
                })
            )
            
            ;; Update counter
            (var-set logistics-counter new-logistics-id)
            
            (ok new-logistics-id)
        )
    )
)

;; Read-only functions
;; Get product batch information
(define-read-only (get-product-batch (batch-id (string-ascii 50)))
    (map-get? product-batches { batch-id: batch-id })
)

;; Get journey step
(define-read-only (get-journey-step (batch-id (string-ascii 50)) (step-id uint))
    (map-get? journey-steps { batch-id: batch-id, step-id: step-id })
)

;; Get processing record
(define-read-only (get-processing-record (batch-id (string-ascii 50)) (process-id uint))
    (map-get? processing-records { batch-id: batch-id, process-id: process-id })
)

;; Get logistics record
(define-read-only (get-logistics-record (batch-id (string-ascii 50)) (logistics-id uint))
    (map-get? logistics-records { batch-id: batch-id, logistics-id: logistics-id })
)

;; Get package details
(define-read-only (get-package-details (batch-id (string-ascii 50)))
    (map-get? package-details { batch-id: batch-id })
)

;; Check if handler is authorized
(define-read-only (is-handler-authorized (handler principal))
    (default-to false (get authorized (map-get? authorized-handlers { handler: handler })))
)

;; Get current step count
(define-read-only (get-step-count)
    (var-get step-counter)
)

;; Get current handler for batch
(define-read-only (get-current-handler (batch-id (string-ascii 50)))
    (match (map-get? product-batches { batch-id: batch-id })
        batch-data (some (get current-handler batch-data))
        none
    )
)

;; Check if product is organic certified
(define-read-only (is-organic-certified (batch-id (string-ascii 50)))
    (match (map-get? product-batches { batch-id: batch-id })
        batch-data (get organic-certified batch-data)
        false
    )
)

;; Transfer batch ownership
(define-public (transfer-batch-ownership (batch-id (string-ascii 50)) (new-owner principal))
    (let 
        (
            (batch-data (unwrap! (map-get? product-batches { batch-id: batch-id }) ERR_BATCH_NOT_FOUND))
        )
        (begin
            ;; Check authorization
            (asserts! (is-eq tx-sender (get batch-owner batch-data)) ERR_UNAUTHORIZED)
            
            ;; Transfer ownership
            (map-set product-batches
                { batch-id: batch-id }
                (merge batch-data {
                    batch-owner: new-owner,
                    current-handler: new-owner,
                    last-updated: stacks-block-height
                })
            )
            
            (ok true)
        )
    )
)


