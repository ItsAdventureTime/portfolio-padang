package role

const (
	Administrator                 = "administrator"
	GeneralManager                = "general_manager"
	DisbursingCheckSigningOfficer = "disbursing_check_signing_officer"
	ProjectManager                = "project_manager"
	ProcurementOfficer            = "procurement_officer"
	FabricationSupervisor         = "fabrication_supervisor"
	FinanceStaff                  = "finance_staff"
	BillingClerk                  = "billing_clerk"
	InventoryClerk                = "inventory_clerk"
	Viewer                        = "viewer"
)

var all = map[string]struct{}{
	Administrator: {}, GeneralManager: {}, DisbursingCheckSigningOfficer: {},
	ProjectManager: {}, ProcurementOfficer: {}, FabricationSupervisor: {},
	FinanceStaff: {}, BillingClerk: {}, InventoryClerk: {}, Viewer: {},
}

func Valid(value string) bool { _, ok := all[value]; return ok }

func All() []string {
	return []string{Administrator, GeneralManager, DisbursingCheckSigningOfficer,
		ProjectManager, ProcurementOfficer, FabricationSupervisor, FinanceStaff,
		BillingClerk, InventoryClerk, Viewer}
}
