pageextension 50563 "Ext. VAT Product Post. Groups" extends "VAT Product Posting Groups"
{
    layout
    {
        addlast(Control1)
        {
            field("Type VAT"; Rec."Type VAT")
            {
                ApplicationArea = All;

            }
        }
    }

    actions
    {
    }
}