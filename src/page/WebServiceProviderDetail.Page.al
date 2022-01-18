page 50562 "Web Service Provider Detail"
{
    PageType = List;
    SourceTable = "Web Service Provider Detail";

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(Code; Rec.Codigo)
                {
                    ApplicationArea = All;
                    Editable = False;
                }
                field(Method; Rec.Metodo)
                {
                    ApplicationArea = All;
                }
                field(URL; Rec.URL)
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ActionName)
            {
                ApplicationArea = All;

                trigger OnAction()
                begin

                end;
            }
        }
    }

    var
        myInt: Integer;
}