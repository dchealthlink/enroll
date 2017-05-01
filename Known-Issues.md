
# Known Issues and Clarifications

## Enroll Mobile API Server v0.1.3
- Plan years that have completed Open Enrollment, but have not yet begun coverage, are in the "in open enrollment" drawer in the apps. The server could adjust this (placing the plans into Pending Renewals) by suppressing the `open_enrollment_ends` date sent in JSON as irrelevant; there's an argument at least that this would be clearer.

### Issues

### Clarifications
- Broker clients which have no current or upcoming plans are listed in the broker employers list. This is by design; they are still clients of the brokers to whom they are assigned. This includes clients who have left the exchange; these are not marked in any particular way.  

