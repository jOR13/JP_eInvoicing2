pageextension 50562 "GenLedgerSetup" extends "General Ledger Setup"
{
    layout
    {
        // Add changes to page layout here
        addafter(General)
        {
            group("E-Invoice")
            {
                field("E-Invoice Service"; Rec."Servicio Facturacion E")
                {
                    ApplicationArea = All;
                }
                field("E-Invoice Code"; Rec."Codigo Facturacion E.")
                {
                    ApplicationArea = All;
                }
                field("Tax ID Country"; Rec."Codigo Pais")
                {
                    ApplicationArea = All;
                }
            }

        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
}