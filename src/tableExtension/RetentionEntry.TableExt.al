tableextension 50566 "ExtRetentionEntry" extends "LOCPE_Retention Entry"
{
    fields
    {
        field(50200; FlagEnvio; Integer)
        {
            Caption = 'Enviado TCI';
            DataClassification = ToBeClassified;
        }
    }

    var
        myInt: Integer;
}