tableextension 50563 "ExtGeneralLedgerSetup" extends "General Ledger Setup"
{
    fields
    {
        // Add changes to table fields here
        field(50100; "Servicio Facturacion E"; Code[20])
        {
            DataClassification = ToBeClassified;
            Caption = 'Servicio Facturacion E';
        }
        field(50101; "Codigo Pais"; Code[20])
        {
            DataClassification = ToBeClassified;
            Caption = 'Codigo Pais';
        }
        field(50102; "Codigo Facturacion E."; Code[20])
        {
            DataClassification = ToBeClassified;
            Caption = 'Codigo Facturacion E.';
            TableRelation = "Web Service Provider";
        }
    }

    var
        myInt: Integer;
}