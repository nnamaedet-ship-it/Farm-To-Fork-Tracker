;; Quality Assurance Smart Contract
;; Records quality checks and safety inspections for food supply chain compliance

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u3001))
(define-constant ERR_INSPECTION_NOT_FOUND (err u3002))
(define-constant ERR_TEST_NOT_FOUND (err u3003))
(define-constant ERR_INVALID_INSPECTION_DATA (err u3004))
(define-constant ERR_INVALID_TEST_DATA (err u3005))
(define-constant ERR_INVALID_PARAMETERS (err u3006))
(define-constant ERR_INSPECTOR_NOT_AUTHORIZED (err u3007))
(define-constant ERR_BATCH_NOT_FOUND (err u3008))
(define-constant ERR_INVALID_TEST_RESULTS (err u3009))
(define-constant ERR_CERTIFICATION_EXPIRED (err u3010))
(define-constant ERR_INVALID_QUALITY_GRADE (err u3011))
(define-constant ERR_SAMPLE_NOT_FOUND (err u3012))
(define-constant ERR_VIOLATION_NOT_FOUND (err u3013))
(define-constant ERR_CERTIFICATION_NOT_FOUND (err u3014))

;; Quality status constants
(define-constant QUALITY_STATUS_PENDING u1)
(define-constant QUALITY_STATUS_PASSED u2)
(define-constant QUALITY_STATUS_FAILED u3)
(define-constant QUALITY_STATUS_CONDITIONAL u4)
(define-constant QUALITY_STATUS_RECALLED u5)

;; Test type constants
(define-constant TEST_TYPE_MICROBIOLOGICAL u1)
(define-constant TEST_TYPE_CHEMICAL u2)
(define-constant TEST_TYPE_PESTICIDE u3)
(define-constant TEST_TYPE_NUTRITIONAL u4)
(define-constant TEST_TYPE_ALLERGEN u5)
(define-constant TEST_TYPE_HEAVY_METALS u6)
(define-constant TEST_TYPE_SENSORY u7)

;; Inspection type constants
(define-constant INSPECTION_TYPE_SAFETY u1)
(define-constant INSPECTION_TYPE_QUALITY u2)
(define-constant INSPECTION_TYPE_COMPLIANCE u3)
(define-constant INSPECTION_TYPE_CERTIFICATION u4)
(define-constant INSPECTION_TYPE_AUDIT u5)

;; Contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Data structures
;; Quality inspection records
(define-map quality-inspections
    { inspection-id: uint }
    {
        batch-id: (string-ascii 50),
        inspector: principal,
        inspection-type: uint,
        inspection-date: uint,
        location: (string-ascii 200),
        product-type: (string-ascii 100),
        quantity-inspected-kg: uint,
        quality-grade: (string-ascii 20),
        overall-status: uint,
        compliance-score: uint,
        temperature-check: bool,
        packaging-check: bool,
        labeling-check: bool,
        documentation-check: bool,
        findings: (string-ascii 1000),
        recommendations: (string-ascii 1000),
        corrective-actions: (string-ascii 1000),
        next-inspection-date: uint,
        certification-maintained: bool
    }
)

;; Laboratory test results
(define-map lab-test-results
    { test-id: uint }
    {
        batch-id: (string-ascii 50),
        sample-id: (string-ascii 50),
        test-type: uint,
        test-date: uint,
        laboratory: principal,
        test-method: (string-ascii 100),
        test-parameters: (list 20 (string-ascii 100)),
        test-results: (list 20 (string-ascii 200)),
        pass-fail-status: uint,
        detection-limit: (string-ascii 50),
        measurement-unit: (string-ascii 20),
        reference-standards: (string-ascii 200),
        analyst: (string-ascii 100),
        equipment-used: (string-ascii 200),
        test-duration-hours: uint,
        test-notes: (string-ascii 500),
        validation-status: bool
    }
)

;; Sample collection records
(define-map sample-records
    { sample-id: (string-ascii 50) }
    {
        batch-id: (string-ascii 50),
        collector: principal,
        collection-date: uint,
        collection-location: (string-ascii 200),
        sample-type: (string-ascii 100),
        sample-size-grams: uint,
        storage-conditions: (string-ascii 200),
        preservation-method: (string-ascii 100),
        chain-of-custody: (string-ascii 500),
        expiry-date: uint,
        temperature-maintained: bool,
        collection-notes: (string-ascii 500)
    }
)

;; Compliance violations
(define-map compliance-violations
    { violation-id: uint }
    {
        batch-id: (string-ascii 50),
        inspection-id: uint,
        violation-type: (string-ascii 100),
        severity-level: uint,
        description: (string-ascii 1000),
        regulatory-reference: (string-ascii 200),
        detected-date: uint,
        reported-by: principal,
        corrective-action-required: bool,
        corrective-action-deadline: uint,
        status: (string-ascii 50),
        resolution-date: (optional uint),
        resolution-notes: (string-ascii 500)
    }
)

;; Quality certifications
(define-map quality-certifications
    { cert-id: uint }
    {
        batch-id: (string-ascii 50),
        certification-type: (string-ascii 100),
        certifying-body: principal,
        issue-date: uint,
        expiry-date: uint,
        certificate-number: (string-ascii 100),
        scope: (string-ascii 500),
        standards-compliance: (list 10 (string-ascii 100)),
        audit-score: uint,
        conditions: (string-ascii 500),
        renewal-required: bool,
        status: bool
    }
)

;; Counters for unique IDs
(define-data-var inspection-counter uint u0)
(define-data-var test-counter uint u0)
(define-data-var violation-counter uint u0)
(define-data-var cert-counter uint u0)

;; Authorized inspectors and laboratories
(define-map authorized-inspectors 
    { inspector: principal } 
    { 
        authorized: bool, 
        specialization: (string-ascii 100),
        certification-number: (string-ascii 50),
        certification-expiry: uint,
        accreditation-body: (string-ascii 100)
    }
)

(define-map authorized-laboratories
    { lab: principal }
    {
        authorized: bool,
        accreditation: (string-ascii 100),
        test-capabilities: (list 10 (string-ascii 100)),
        certification-expiry: uint,
        location: (string-ascii 200)
    }
)

;; Admin functions
;; Authorize inspector
(define-public (authorize-inspector 
    (inspector principal) 
    (specialization (string-ascii 100))
    (certification-number (string-ascii 50))
    (certification-expiry uint)
    (accreditation-body (string-ascii 100))
)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (ok (map-set authorized-inspectors 
            { inspector: inspector } 
            { 
                authorized: true, 
                specialization: specialization,
                certification-number: certification-number,
                certification-expiry: certification-expiry,
                accreditation-body: accreditation-body
            }
        ))
    )
)

;; Authorize laboratory
(define-public (authorize-laboratory
    (lab principal)
    (accreditation (string-ascii 100))
    (test-capabilities (list 10 (string-ascii 100)))
    (certification-expiry uint)
    (location (string-ascii 200))
)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (ok (map-set authorized-laboratories
            { lab: lab }
            {
                authorized: true,
                accreditation: accreditation,
                test-capabilities: test-capabilities,
                certification-expiry: certification-expiry,
                location: location
            }
        ))
    )
)

;; Core quality assurance functions
;; Conduct quality inspection
(define-public (conduct-quality-inspection
    (batch-id (string-ascii 50))
    (inspection-type uint)
    (location (string-ascii 200))
    (product-type (string-ascii 100))
    (quantity-inspected-kg uint)
    (quality-grade (string-ascii 20))
    (compliance-score uint)
    (temperature-check bool)
    (packaging-check bool)
    (labeling-check bool)
    (documentation-check bool)
    (findings (string-ascii 1000))
    (recommendations (string-ascii 1000))
    (corrective-actions (string-ascii 1000))
    (certification-maintained bool)
)
    (let 
        (
            (inspector-data (unwrap! (map-get? authorized-inspectors { inspector: tx-sender }) ERR_INSPECTOR_NOT_AUTHORIZED))
            (new-inspection-id (+ (var-get inspection-counter) u1))
            (current-time stacks-block-height)
            (overall-status (if (and temperature-check packaging-check labeling-check documentation-check (>= compliance-score u70))
                QUALITY_STATUS_PASSED
                (if (>= compliance-score u50) QUALITY_STATUS_CONDITIONAL QUALITY_STATUS_FAILED)
            ))
        )
        (begin
            ;; Validate input parameters
            (asserts! (> (len batch-id) u0) ERR_INVALID_PARAMETERS)
            (asserts! (> quantity-inspected-kg u0) ERR_INVALID_PARAMETERS)
            (asserts! (<= compliance-score u100) ERR_INVALID_PARAMETERS)
            (asserts! (and (>= inspection-type u1) (<= inspection-type u5)) ERR_INVALID_PARAMETERS)
            (asserts! (> (get certification-expiry inspector-data) current-time) ERR_CERTIFICATION_EXPIRED)
            
            ;; Record inspection
            (map-set quality-inspections
                { inspection-id: new-inspection-id }
                {
                    batch-id: batch-id,
                    inspector: tx-sender,
                    inspection-type: inspection-type,
                    inspection-date: current-time,
                    location: location,
                    product-type: product-type,
                    quantity-inspected-kg: quantity-inspected-kg,
                    quality-grade: quality-grade,
                    overall-status: overall-status,
                    compliance-score: compliance-score,
                    temperature-check: temperature-check,
                    packaging-check: packaging-check,
                    labeling-check: labeling-check,
                    documentation-check: documentation-check,
                    findings: findings,
                    recommendations: recommendations,
                    corrective-actions: corrective-actions,
                    next-inspection-date: (+ current-time u4380), ;; 6 months
                    certification-maintained: certification-maintained
                }
            )
            
            ;; Update counter
            (var-set inspection-counter new-inspection-id)
            
            (ok new-inspection-id)
        )
    )
)

;; Collect sample for testing
(define-public (collect-sample
    (sample-id (string-ascii 50))
    (batch-id (string-ascii 50))
    (collection-location (string-ascii 200))
    (sample-type (string-ascii 100))
    (sample-size-grams uint)
    (storage-conditions (string-ascii 200))
    (preservation-method (string-ascii 100))
    (chain-of-custody (string-ascii 500))
    (expiry-date uint)
    (temperature-maintained bool)
    (collection-notes (string-ascii 500))
)
    (let 
        (
            (current-time stacks-block-height)
        )
        (begin
            ;; Validate parameters
            (asserts! (> (len sample-id) u0) ERR_INVALID_PARAMETERS)
            (asserts! (> (len batch-id) u0) ERR_INVALID_PARAMETERS)
            (asserts! (> sample-size-grams u0) ERR_INVALID_PARAMETERS)
            (asserts! (> expiry-date current-time) ERR_INVALID_PARAMETERS)
            
            ;; Record sample collection
            (map-set sample-records
                { sample-id: sample-id }
                {
                    batch-id: batch-id,
                    collector: tx-sender,
                    collection-date: current-time,
                    collection-location: collection-location,
                    sample-type: sample-type,
                    sample-size-grams: sample-size-grams,
                    storage-conditions: storage-conditions,
                    preservation-method: preservation-method,
                    chain-of-custody: chain-of-custody,
                    expiry-date: expiry-date,
                    temperature-maintained: temperature-maintained,
                    collection-notes: collection-notes
                }
            )
            
            (ok sample-id)
        )
    )
)

;; Record laboratory test results
(define-public (record-test-results
    (batch-id (string-ascii 50))
    (sample-id (string-ascii 50))
    (test-type uint)
    (test-method (string-ascii 100))
    (test-parameters (list 20 (string-ascii 100)))
    (test-results (list 20 (string-ascii 200)))
    (detection-limit (string-ascii 50))
    (measurement-unit (string-ascii 20))
    (reference-standards (string-ascii 200))
    (analyst (string-ascii 100))
    (equipment-used (string-ascii 200))
    (test-duration-hours uint)
    (test-notes (string-ascii 500))
    (validation-status bool)
)
    (let 
        (
            (lab-data (unwrap! (map-get? authorized-laboratories { lab: tx-sender }) ERR_UNAUTHORIZED))
            (sample-data (unwrap! (map-get? sample-records { sample-id: sample-id }) ERR_SAMPLE_NOT_FOUND))
            (new-test-id (+ (var-get test-counter) u1))
            (current-time stacks-block-height)
            ;; Determine pass/fail status based on test results (simplified logic)
            (pass-fail-status (if validation-status QUALITY_STATUS_PASSED QUALITY_STATUS_FAILED))
        )
        (begin
            ;; Validate laboratory authorization
            (asserts! (> (get certification-expiry lab-data) current-time) ERR_CERTIFICATION_EXPIRED)
            
            ;; Validate test parameters
            (asserts! (and (>= test-type u1) (<= test-type u7)) ERR_INVALID_PARAMETERS)
            (asserts! (> (len test-method) u0) ERR_INVALID_TEST_DATA)
            (asserts! (is-eq batch-id (get batch-id sample-data)) ERR_INVALID_PARAMETERS)
            
            ;; Record test results
            (map-set lab-test-results
                { test-id: new-test-id }
                {
                    batch-id: batch-id,
                    sample-id: sample-id,
                    test-type: test-type,
                    test-date: current-time,
                    laboratory: tx-sender,
                    test-method: test-method,
                    test-parameters: test-parameters,
                    test-results: test-results,
                    pass-fail-status: pass-fail-status,
                    detection-limit: detection-limit,
                    measurement-unit: measurement-unit,
                    reference-standards: reference-standards,
                    analyst: analyst,
                    equipment-used: equipment-used,
                    test-duration-hours: test-duration-hours,
                    test-notes: test-notes,
                    validation-status: validation-status
                }
            )
            
            ;; Update counter
            (var-set test-counter new-test-id)
            
            (ok new-test-id)
        )
    )
)

;; Record compliance violation
(define-public (record-violation
    (batch-id (string-ascii 50))
    (inspection-id uint)
    (violation-type (string-ascii 100))
    (severity-level uint)
    (description (string-ascii 1000))
    (regulatory-reference (string-ascii 200))
    (corrective-action-required bool)
    (corrective-action-deadline uint)
)
    (let 
        (
            (inspector-data (unwrap! (map-get? authorized-inspectors { inspector: tx-sender }) ERR_INSPECTOR_NOT_AUTHORIZED))
            (new-violation-id (+ (var-get violation-counter) u1))
            (current-time stacks-block-height)
        )
        (begin
            ;; Validate parameters
            (asserts! (> (len batch-id) u0) ERR_INVALID_PARAMETERS)
            (asserts! (and (>= severity-level u1) (<= severity-level u5)) ERR_INVALID_PARAMETERS)
            (asserts! (> (len description) u0) ERR_INVALID_PARAMETERS)
            
            ;; Record violation
            (map-set compliance-violations
                { violation-id: new-violation-id }
                {
                    batch-id: batch-id,
                    inspection-id: inspection-id,
                    violation-type: violation-type,
                    severity-level: severity-level,
                    description: description,
                    regulatory-reference: regulatory-reference,
                    detected-date: current-time,
                    reported-by: tx-sender,
                    corrective-action-required: corrective-action-required,
                    corrective-action-deadline: corrective-action-deadline,
                    status: "open",
                    resolution-date: none,
                    resolution-notes: ""
                }
            )
            
            ;; Update counter
            (var-set violation-counter new-violation-id)
            
            (ok new-violation-id)
        )
    )
)

;; Issue quality certification
(define-public (issue-quality-certification
    (batch-id (string-ascii 50))
    (certification-type (string-ascii 100))
    (expiry-date uint)
    (certificate-number (string-ascii 100))
    (scope (string-ascii 500))
    (standards-compliance (list 10 (string-ascii 100)))
    (audit-score uint)
    (conditions (string-ascii 500))
    (renewal-required bool)
)
    (let 
        (
            (inspector-data (unwrap! (map-get? authorized-inspectors { inspector: tx-sender }) ERR_INSPECTOR_NOT_AUTHORIZED))
            (new-cert-id (+ (var-get cert-counter) u1))
            (current-time stacks-block-height)
        )
        (begin
            ;; Validate parameters
            (asserts! (> (len batch-id) u0) ERR_INVALID_PARAMETERS)
            (asserts! (> expiry-date current-time) ERR_INVALID_PARAMETERS)
            (asserts! (<= audit-score u100) ERR_INVALID_PARAMETERS)
            (asserts! (>= audit-score u70) ERR_INVALID_QUALITY_GRADE) ;; Minimum score for certification
            
            ;; Issue certification
            (map-set quality-certifications
                { cert-id: new-cert-id }
                {
                    batch-id: batch-id,
                    certification-type: certification-type,
                    certifying-body: tx-sender,
                    issue-date: current-time,
                    expiry-date: expiry-date,
                    certificate-number: certificate-number,
                    scope: scope,
                    standards-compliance: standards-compliance,
                    audit-score: audit-score,
                    conditions: conditions,
                    renewal-required: renewal-required,
                    status: true
                }
            )
            
            ;; Update counter
            (var-set cert-counter new-cert-id)
            
            (ok new-cert-id)
        )
    )
)

;; Read-only functions
;; Get quality inspection
(define-read-only (get-quality-inspection (inspection-id uint))
    (map-get? quality-inspections { inspection-id: inspection-id })
)

;; Get test results
(define-read-only (get-test-results (test-id uint))
    (map-get? lab-test-results { test-id: test-id })
)

;; Get sample record
(define-read-only (get-sample-record (sample-id (string-ascii 50)))
    (map-get? sample-records { sample-id: sample-id })
)

;; Get compliance violation
(define-read-only (get-compliance-violation (violation-id uint))
    (map-get? compliance-violations { violation-id: violation-id })
)

;; Get quality certification
(define-read-only (get-quality-certification (cert-id uint))
    (map-get? quality-certifications { cert-id: cert-id })
)

;; Check if inspector is authorized
(define-read-only (is-inspector-authorized (inspector principal))
    (match (map-get? authorized-inspectors { inspector: inspector })
        inspector-data (and 
            (get authorized inspector-data)
            (> (get certification-expiry inspector-data) stacks-block-height)
        )
        false
    )
)

;; Check if laboratory is authorized
(define-read-only (is-laboratory-authorized (lab principal))
    (match (map-get? authorized-laboratories { lab: lab })
        lab-data (and 
            (get authorized lab-data)
            (> (get certification-expiry lab-data) stacks-block-height)
        )
        false
    )
)

;; Get inspection count
(define-read-only (get-inspection-count)
    (var-get inspection-counter)
)

;; Get test count
(define-read-only (get-test-count)
    (var-get test-counter)
)

;; Check batch quality status based on latest inspection
(define-read-only (get-batch-quality-status (batch-id (string-ascii 50)))
    ;; This would need to iterate through inspections to find the latest one
    ;; Simplified implementation returns a default status
    QUALITY_STATUS_PENDING
)

;; Utility functions
;; Resolve violation (inspector only)
(define-public (resolve-violation 
    (violation-id uint) 
    (resolution-notes (string-ascii 500))
)
    (let 
        (
            (violation-data (unwrap! (map-get? compliance-violations { violation-id: violation-id }) ERR_VIOLATION_NOT_FOUND))
            (inspector-data (unwrap! (map-get? authorized-inspectors { inspector: tx-sender }) ERR_INSPECTOR_NOT_AUTHORIZED))
        )
        (begin
            ;; Update violation status
            (map-set compliance-violations
                { violation-id: violation-id }
                (merge violation-data {
                    status: "resolved",
                    resolution-date: (some stacks-block-height),
                    resolution-notes: resolution-notes
                })
            )
            
            (ok true)
        )
    )
)

;; Revoke quality certification (admin only)
(define-public (revoke-certification (cert-id uint))
    (let 
        (
            (cert-data (unwrap! (map-get? quality-certifications { cert-id: cert-id }) ERR_CERTIFICATION_NOT_FOUND))
        )
        (begin
            (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
            
            ;; Revoke certification
            (map-set quality-certifications
                { cert-id: cert-id }
                (merge cert-data { status: false })
            )
            
            (ok true)
        )
    )
)

;; title: quality-assurance
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

