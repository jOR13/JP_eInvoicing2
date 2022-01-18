pageextension 50566 "Ext. Posted Sales Invoice Sub" extends "Posted Sales Invoice Subform"
{
    layout
    {
        addafter(Description)
        {
            field("Descripcion Larga"; Rec."Descripcion Larga")
            {
                ApplicationArea = All;
                ToolTip = 'Dinamika';
                MultiLine = true;
            }
        }
    }

    actions
    {
    }
}