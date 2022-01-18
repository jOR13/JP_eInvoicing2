table 50563 "Web Service Provider Detail"
{
    DataClassification = ToBeClassified;
    Caption = 'Detalle de web service provider';

    fields
    {
        field(1; Codigo; Code[20])
        {
            DataClassification = ToBeClassified;
            Caption = 'Codigo';
        }
        field(3; Metodo; Option)
        {
            OptionMembers = " ","Registro de Documento","Estado Documento","Descarga Documento","Actualizar Estado","Registro de Retencion","Reversion de Retencion";
            OptionCaption = ' ,Registro de Documento,Estado Documento,Descarga Documento,Actualizar Estado,Registro de Retencion,Reversion de Retencion';
            Caption = 'Metodo';
        }
        field(4; URL; Text[250])
        {
            DataClassification = ToBeClassified;
            Caption = 'URL';
        }
    }

    keys
    {
        key(PK; Codigo, Metodo)
        {
            Clustered = true;
        }
    }


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