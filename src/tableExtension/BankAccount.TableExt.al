tableextension 50565 "CuentasBancarias" extends "Bank Account"
{
    fields
    {
        field(50100; "EsLeyenda"; Boolean)
        {
            DataClassification = ToBeClassified;
            Caption = 'Es leyenda de Impresion';
        }
        field(50101; "Orden"; Integer)
        {
            DataClassification = ToBeClassified;
            Caption = 'Orden Impresion';
        }
        field(50102; "CCI"; Text[30])
        {
            DataClassification = ToBeClassified;
            Caption = 'CCI';
        }
    }

    var
        myInt: Integer;
}