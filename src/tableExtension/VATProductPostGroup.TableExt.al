tableextension 50564 "Ext. VAT Product Post. Group" extends "VAT Product Posting Group"
{
    fields
    {
        field(50100; "Type VAT"; Enum "Tipo Igv Sunat")
        {
            Caption = 'Tipo VAT';
            DataClassification = ToBeClassified;

        }
    }
}