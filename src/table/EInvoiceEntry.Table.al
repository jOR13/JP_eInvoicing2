table 50561 "E-Invoice Entry"
{
    DataClassification = ToBeClassified;
    Caption = 'Entrada Facturacion E';

    fields
    {
        field(1; "Document Type"; Enum "Tipo Documento")
        {
            DataClassification = ToBeClassified;
            Caption = 'Tipo Documento';
        }
        field(2; "Document No."; Code[20])
        {
            DataClassification = ToBeClassified;
            Caption = 'No. Documento';
        }
        Field(10; "Posting Date"; Date)
        {
            DataClassification = ToBeClassified;
            Caption = 'Fecha de Proceso';
        }
        field(11; "Last Date"; Date)
        {
            DataClassification = ToBeClassified;
            Caption = 'Fecha de Modificacion';
        }
        field(12; "User ID"; Code[50])
        {
            DataClassification = ToBeClassified;
            Caption = 'ID Usuario';
        }
        Field(15; "Elec. Document Status"; enum "Estado Documento")
        {
            DataClassification = ToBeClassified;
            Caption = 'Estado de Documento';
        }

        field(20; "Customer No."; Code[20])
        {
            DataClassification = ToBeClassified;
            Caption = 'No. Cliente';
        }
        field(21; "Customer Name"; Text[100])
        {
            DataClassification = ToBeClassified;
            Caption = 'Nombre de Cliente';
        }
        field(22; "Custemer Name 2"; Text[100])
        {
            DataClassification = ToBeClassified;
            Caption = 'Nombre de Cliente';
        }
        Field(40; " Posting Date Document"; Date)
        {
            DataClassification = ToBeClassified;
            Caption = 'Fecha Contabilizacion Doc.';
        }
        Field(41; Amount; Decimal)
        {
            DataClassification = ToBeClassified;
            Caption = 'Monto';
        }
        field(100; "File Base64"; blob)
        {
            DataClassification = ToBeClassified;
            Caption = 'File Base64';
        }
        Field(101; "Document XML"; BLOB)
        {
            DataClassification = ToBeClassified;
            Caption = 'Documento XML';
        }
        field(102; "Document PDF"; BLOB)
        {
            DataClassification = ToBeClassified;
            Caption = 'Documento PDF';
        }
        Field(110; "Error Code"; Code[20])
        {
            DataClassification = ToBeClassified;
            Caption = 'Codigo de error';
        }
        Field(111; "Error Description"; Text[250])
        {
            DataClassification = ToBeClassified;
            Caption = 'Error Descripcion';
        }
        Field(112; "Response Document"; Blob)
        {
            DataClassification = ToBeClassified;
        }
        field(113; "Response Web Service"; Text[250])
        {
            DataClassification = ToBeClassified;
            Caption = 'Respuesta Web Service';
        }
        Field(114; "Response Code"; Text[30])
        {
            DataClassification = ToBeClassified;
            Caption = 'Codigo de respuesta';
        }
        Field(115; "Response Observations"; Text[250])
        {
            DataClassification = ToBeClassified;
            Caption = 'Respuesta de Observaciones';
        }
        Field(116; "SUNAT DocType"; Code[20])
        {
            DataClassification = ToBeClassified;
            Caption = 'Tipo Documento Sunat';
        }
        Field(117; "Codigo Hash"; Text[50])
        {
            DataClassification = ToBeClassified;
            Caption = 'Codigo Hash';
        }
        field(118; "Nombre Document PDF"; Text[50])
        {
            DataClassification = ToBeClassified;
            Caption = 'Nombre Documento PDF';
        }
    }

    keys
    {
        key(PK; "Document Type", "Document No.")
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
        "Last Date" := Today;
    end;

    trigger OnDelete()
    begin

    end;

    trigger OnRename()
    begin

    end;
}