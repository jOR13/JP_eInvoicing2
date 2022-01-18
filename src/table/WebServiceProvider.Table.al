table 50562 "Web Service Provider"
{
    DataClassification = ToBeClassified;
    Caption = 'Servicio Web Provider';
    fields
    {
        field(1; Codigo; Code[20])
        {
            DataClassification = ToBeClassified;
            Caption = 'Codigo';
        }
        field(2; Descripcion; Text[50])
        {
            DataClassification = ToBeClassified;
            Caption = 'Descripcion';
        }
        field(3; Tipo; Option)
        {
            OptionMembers = "Produccion","Prueba";
            Caption = 'Tipo';
        }
        field(4; "Usuario"; Text[50])
        {
            DataClassification = ToBeClassified;
            Caption = 'Usuario';
        }
        field(5; Contraseña; Text[50])
        {
            DataClassification = ToBeClassified;
            Caption = 'Contraseña';
        }
    }

    keys
    {
        key(PK; Codigo)
        {
            Clustered = true;
        }
    }

    var
        myInt: Integer;

    trigger OnInsert()
    begin

    end;

    trigger OnModify()
    begin

    end;

    trigger OnDelete()
    begin

    end;

    trigger OnRename()
    begin

    end;

}