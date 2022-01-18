tableextension 50568 "ExtSalesLine" extends "Sales Line"
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
