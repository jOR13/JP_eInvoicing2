tableextension 50561 "ExtSalesInvoiceHeader" extends "Sales Invoice Header"
{
    fields
    {
        // Add changes to table fields here
        field(50100; Processed; Boolean)
        {
            Caption = 'Processed';
            DataClassification = ToBeClassified;
        }
        field(50101; Status; Enum "Estado Documento")
        {
            Caption = 'Status';
            FieldClass = FlowField;
            CalcFormula = lookup("E-Invoice Entry"."Elec. Document Status" where("Document No." = field("No.")));
        }
    }

    var
        myInt: Integer;
}