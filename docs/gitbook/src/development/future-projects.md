# Future Projects

The following capabilities are separate projects, not optional switches in
setup-cm v1:

- production deployment;
- co-management;
- Patch My PC;
- reporting expansion;
- distributed MECM topology;
- alternate hypervisors and provisioning paths;
- additional clients or broad collections;
- tenant integrations;
- client-wide security-policy changes;
- VM rebuild or snapshot rollback;
- historical ConfigMgr-object deletion.

Each needs an independent design, explicit target and credential boundary,
rollback plan, tests, and live acceptance. None may weaken the LabZ1 identity,
hash, one-device collection, trust, or no-rebuild gates to make a v1 rerun
pass. The detailed project boundaries are maintained in
[`docs/FUTURE-PROJECTS.md`](https://github.com/AdamGell/setup-cm/blob/main/docs/FUTURE-PROJECTS.md).
