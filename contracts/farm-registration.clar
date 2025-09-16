;; Farm Registration Smart Contract
;; Manages farm registration, certifications, and compliance for sustainable agriculture

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_FARM_NOT_FOUND (err u1002))
(define-constant ERR_FARM_ALREADY_EXISTS (err u1003))
(define-constant ERR_INVALID_FARM_DATA (err u1004))
(define-constant ERR_CERTIFICATION_NOT_FOUND (err u1005))
(define-constant ERR_CERTIFICATION_EXPIRED (err u1006))
(define-constant ERR_INVALID_CERTIFICATION_DATA (err u1007))
(define-constant ERR_FARM_NOT_ACTIVE (err u1008))
(define-constant ERR_INVALID_PARAMETERS (err u1009))
(define-constant ERR_FARM_SUSPENDED (err u1010))

;; Farm status constants
(define-constant FARM_STATUS_PENDING u0)
(define-constant FARM_STATUS_ACTIVE u1)
(define-constant FARM_STATUS_SUSPENDED u2)
(define-constant FARM_STATUS_DEACTIVATED u3)

;; Certification type constants
(define-constant CERT_TYPE_ORGANIC u1)
(define-constant CERT_TYPE_SUSTAINABLE u2)
(define-constant CERT_TYPE_FAIR_TRADE u3)
(define-constant CERT_TYPE_BIODYNAMIC u4)
(define-constant CERT_TYPE_RAINFOREST u5)

;; Contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Data structures
;; Farm information structure
(define-map farms 
    { farm-id: uint }
    {
        owner: principal,
        name: (string-ascii 100),
        location: (string-ascii 200),
        size-hectares: uint,
        farm-type: (string-ascii 50),
        registration-date: uint,
        status: uint,
        contact-info: (string-ascii 100),
        description: (string-ascii 500),
        last-audit-date: uint,
        next-audit-due: uint
    }
)

;; Farm certifications structure
(define-map farm-certifications
    { farm-id: uint, cert-id: uint }
    {
        cert-type: uint,
        cert-name: (string-ascii 100),
        issuing-body: (string-ascii 100),
        issue-date: uint,
        expiry-date: uint,
        cert-number: (string-ascii 50),
        status: bool,
        verification-hash: (buff 32)
    }
)

;; Farm audit records
(define-map farm-audits
    { farm-id: uint, audit-id: uint }
    {
        auditor: principal,
        audit-date: uint,
        audit-type: (string-ascii 50),
        compliance-score: uint,
        findings: (string-ascii 1000),
        recommendations: (string-ascii 1000),
        status: (string-ascii 20),
        next-audit-date: uint
    }
)

;; Farm production capacity
(define-map farm-capacity
    { farm-id: uint }
    {
        crop-types: (list 20 (string-ascii 50)),
        annual-capacity-tons: uint,
        seasonal-production: (string-ascii 200),
        organic-percentage: uint,
        irrigation-type: (string-ascii 50),
        soil-type: (string-ascii 100)
    }
)

;; Counters for unique IDs
(define-data-var farm-counter uint u0)
(define-data-var cert-counter uint u0)
(define-data-var audit-counter uint u0)

;; Authorized auditors
(define-map authorized-auditors { auditor: principal } { authorized: bool, specialization: (string-ascii 100) })

;; Admin functions
;; Authorize an auditor
(define-public (authorize-auditor (auditor principal) (specialization (string-ascii 100)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (ok (map-set authorized-auditors { auditor: auditor } { authorized: true, specialization: specialization }))
    )
)

;; Revoke auditor authorization
(define-public (revoke-auditor (auditor principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (ok (map-delete authorized-auditors { auditor: auditor }))
    )
)

;; Core farm registration functions
;; Register a new farm
(define-public (register-farm 
    (name (string-ascii 100))
    (location (string-ascii 200))
    (size-hectares uint)
    (farm-type (string-ascii 50))
    (contact-info (string-ascii 100))
    (description (string-ascii 500))
)
    (let 
        (
            (new-farm-id (+ (var-get farm-counter) u1))
            (current-time stacks-block-height)
        )
        (begin
            ;; Validate input parameters
            (asserts! (> (len name) u0) ERR_INVALID_PARAMETERS)
            (asserts! (> (len location) u0) ERR_INVALID_PARAMETERS)
            (asserts! (> size-hectares u0) ERR_INVALID_PARAMETERS)
            
            ;; Check if farm already exists for this owner (simplified check)
            (asserts! (is-none (map-get? farms { farm-id: new-farm-id })) ERR_FARM_ALREADY_EXISTS)
            
            ;; Register the farm
            (map-set farms 
                { farm-id: new-farm-id }
                {
                    owner: tx-sender,
                    name: name,
                    location: location,
                    size-hectares: size-hectares,
                    farm-type: farm-type,
                    registration-date: current-time,
                    status: FARM_STATUS_PENDING,
                    contact-info: contact-info,
                    description: description,
                    last-audit-date: u0,
                    next-audit-due: (+ current-time u8760) ;; One year from registration
                }
            )
            
            ;; Update counter
            (var-set farm-counter new-farm-id)
            
            ;; Return farm ID
            (ok new-farm-id)
        )
    )
)

;; Update farm information
(define-public (update-farm-info
    (farm-id uint)
    (name (string-ascii 100))
    (location (string-ascii 200))
    (contact-info (string-ascii 100))
    (description (string-ascii 500))
)
    (let 
        (
            (farm-data (unwrap! (map-get? farms { farm-id: farm-id }) ERR_FARM_NOT_FOUND))
        )
        (begin
            ;; Check authorization
            (asserts! (or (is-eq tx-sender (get owner farm-data)) (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
            
            ;; Update farm information
            (map-set farms 
                { farm-id: farm-id }
                (merge farm-data {
                    name: name,
                    location: location,
                    contact-info: contact-info,
                    description: description
                })
            )
            
            (ok true)
        )
    )
)

;; Certification management
;; Add certification to farm
(define-public (add-certification
    (farm-id uint)
    (cert-type uint)
    (cert-name (string-ascii 100))
    (issuing-body (string-ascii 100))
    (issue-date uint)
    (expiry-date uint)
    (cert-number (string-ascii 50))
    (verification-hash (buff 32))
)
    (let 
        (
            (farm-data (unwrap! (map-get? farms { farm-id: farm-id }) ERR_FARM_NOT_FOUND))
            (new-cert-id (+ (var-get cert-counter) u1))
        )
        (begin
            ;; Check authorization
            (asserts! (or (is-eq tx-sender (get owner farm-data)) (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
            
            ;; Validate certification data
            (asserts! (> (len cert-name) u0) ERR_INVALID_CERTIFICATION_DATA)
            (asserts! (> (len issuing-body) u0) ERR_INVALID_CERTIFICATION_DATA)
            (asserts! (< issue-date expiry-date) ERR_INVALID_CERTIFICATION_DATA)
            (asserts! (> expiry-date stacks-block-height) ERR_CERTIFICATION_EXPIRED)
            
            ;; Add certification
            (map-set farm-certifications
                { farm-id: farm-id, cert-id: new-cert-id }
                {
                    cert-type: cert-type,
                    cert-name: cert-name,
                    issuing-body: issuing-body,
                    issue-date: issue-date,
                    expiry-date: expiry-date,
                    cert-number: cert-number,
                    status: true,
                    verification-hash: verification-hash
                }
            )
            
            ;; Update counter
            (var-set cert-counter new-cert-id)
            
            (ok new-cert-id)
        )
    )
)

;; Set farm production capacity
(define-public (set-farm-capacity
    (farm-id uint)
    (crop-types (list 20 (string-ascii 50)))
    (annual-capacity-tons uint)
    (seasonal-production (string-ascii 200))
    (organic-percentage uint)
    (irrigation-type (string-ascii 50))
    (soil-type (string-ascii 100))
)
    (let 
        (
            (farm-data (unwrap! (map-get? farms { farm-id: farm-id }) ERR_FARM_NOT_FOUND))
        )
        (begin
            ;; Check authorization
            (asserts! (or (is-eq tx-sender (get owner farm-data)) (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
            
            ;; Validate organic percentage
            (asserts! (<= organic-percentage u100) ERR_INVALID_PARAMETERS)
            
            ;; Set capacity information
            (map-set farm-capacity
                { farm-id: farm-id }
                {
                    crop-types: crop-types,
                    annual-capacity-tons: annual-capacity-tons,
                    seasonal-production: seasonal-production,
                    organic-percentage: organic-percentage,
                    irrigation-type: irrigation-type,
                    soil-type: soil-type
                }
            )
            
            (ok true)
        )
    )
)

;; Audit management
;; Conduct farm audit (only authorized auditors)
(define-public (conduct-audit
    (farm-id uint)
    (audit-type (string-ascii 50))
    (compliance-score uint)
    (findings (string-ascii 1000))
    (recommendations (string-ascii 1000))
    (status (string-ascii 20))
)
    (let 
        (
            (farm-data (unwrap! (map-get? farms { farm-id: farm-id }) ERR_FARM_NOT_FOUND))
            (auditor-data (unwrap! (map-get? authorized-auditors { auditor: tx-sender }) ERR_UNAUTHORIZED))
            (new-audit-id (+ (var-get audit-counter) u1))
            (current-time stacks-block-height)
        )
        (begin
            ;; Validate compliance score (0-100)
            (asserts! (<= compliance-score u100) ERR_INVALID_PARAMETERS)
            
            ;; Record audit
            (map-set farm-audits
                { farm-id: farm-id, audit-id: new-audit-id }
                {
                    auditor: tx-sender,
                    audit-date: current-time,
                    audit-type: audit-type,
                    compliance-score: compliance-score,
                    findings: findings,
                    recommendations: recommendations,
                    status: status,
                    next-audit-date: (+ current-time u8760) ;; Next audit in one year
                }
            )
            
            ;; Update farm audit information
            (map-set farms
                { farm-id: farm-id }
                (merge farm-data {
                    last-audit-date: current-time,
                    next-audit-due: (+ current-time u8760)
                })
            )
            
            ;; Update audit counter
            (var-set audit-counter new-audit-id)
            
            ;; Update farm status based on compliance score
            (if (>= compliance-score u70)
                (map-set farms { farm-id: farm-id } (merge farm-data { status: FARM_STATUS_ACTIVE }))
                (map-set farms { farm-id: farm-id } (merge farm-data { status: FARM_STATUS_SUSPENDED }))
            )
            
            (ok new-audit-id)
        )
    )
)

;; Read-only functions
;; Get farm information
(define-read-only (get-farm-info (farm-id uint))
    (map-get? farms { farm-id: farm-id })
)

;; Get farm certification
(define-read-only (get-farm-certification (farm-id uint) (cert-id uint))
    (map-get? farm-certifications { farm-id: farm-id, cert-id: cert-id })
)

;; Get farm capacity
(define-read-only (get-farm-capacity (farm-id uint))
    (map-get? farm-capacity { farm-id: farm-id })
)

;; Get farm audit
(define-read-only (get-farm-audit (farm-id uint) (audit-id uint))
    (map-get? farm-audits { farm-id: farm-id, audit-id: audit-id })
)

;; Check if farm is active
(define-read-only (is-farm-active (farm-id uint))
    (match (map-get? farms { farm-id: farm-id })
        farm-data (is-eq (get status farm-data) FARM_STATUS_ACTIVE)
        false
    )
)

;; Check if certification is valid
(define-read-only (is-certification-valid (farm-id uint) (cert-id uint))
    (match (map-get? farm-certifications { farm-id: farm-id, cert-id: cert-id })
        cert-data (and 
            (get status cert-data)
            (> (get expiry-date cert-data) stacks-block-height)
        )
        false
    )
)

;; Get current farm count
(define-read-only (get-farm-count)
    (var-get farm-counter)
)

;; Get farm owner
(define-read-only (get-farm-owner (farm-id uint))
    (match (map-get? farms { farm-id: farm-id })
        farm-data (some (get owner farm-data))
        none
    )
)

;; Check if auditor is authorized
(define-read-only (is-auditor-authorized (auditor principal))
    (default-to false (get authorized (map-get? authorized-auditors { auditor: auditor })))
)

;; Utility functions
;; Transfer farm ownership
(define-public (transfer-farm-ownership (farm-id uint) (new-owner principal))
    (let 
        (
            (farm-data (unwrap! (map-get? farms { farm-id: farm-id }) ERR_FARM_NOT_FOUND))
        )
        (begin
            ;; Check authorization
            (asserts! (is-eq tx-sender (get owner farm-data)) ERR_UNAUTHORIZED)
            
            ;; Transfer ownership
            (map-set farms
                { farm-id: farm-id }
                (merge farm-data { owner: new-owner })
            )
            
            (ok true)
        )
    )
)

;; Deactivate farm (admin only)
(define-public (deactivate-farm (farm-id uint))
    (let 
        (
            (farm-data (unwrap! (map-get? farms { farm-id: farm-id }) ERR_FARM_NOT_FOUND))
        )
        (begin
            ;; Check authorization (only contract owner)
            (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
            
            ;; Deactivate farm
            (map-set farms
                { farm-id: farm-id }
                (merge farm-data { status: FARM_STATUS_DEACTIVATED })
            )
            
            (ok true)
        )
    )
)


