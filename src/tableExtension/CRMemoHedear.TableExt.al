tableextension 50562 "ExtCRMemoHeader" extends "Sales Cr.Memo Header"
{
    fields
    {
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
}

