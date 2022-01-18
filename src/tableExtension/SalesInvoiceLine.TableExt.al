tableextension 50567 "ExtSalesInvoiceLine" extends "Sales Invoice Line"
{
    fields
    {
        // Add changes to table fields here
        field(50361; "Descripcion Larga"; Text[700])
        {
            Caption = 'Descripcion Larga';
        }
    }

    var
        myInt: Integer;
}
