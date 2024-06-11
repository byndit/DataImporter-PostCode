codeunit 60000 "PC Post Code Processor" implements "BYD DI IProcessor"
{
    Access = Internal;

    procedure GetTableNo(): Integer
    begin
        exit(Database::"Post Code")
    end;

    procedure GetTemplateFields(var Rec: Record "BYD DI Template Field" temporary)
    var
        PostCode: Record "Post Code";
    begin
        CreateField(Rec, PostCode.FieldNo(Code), false, false);
        CreateField(Rec, PostCode.FieldNo(City), false, true);
        CreateField(Rec, PostCode.FieldNo("Country/Region Code"), false, false);
        CreateField(Rec, PostCode.FieldNo(County), false, false);
        CreateField(Rec, PostCode.FieldNo("Search City"), false, false);
        CreateField(Rec, PostCode.FieldNo("Time Zone"), false, false);
    end;

    procedure OnChunkLoaded(Rec: Record "BYD DI Template"; Chunk: JsonArray)
    begin
        ProcessChunk(Rec, Chunk);
    end;

    local procedure ProcessChunk(Rec: Record "BYD DI Template"; Chunk: JsonArray)
    var
        TempPostCode: Record "Post Code" temporary;
        ConfigValidateMgt: Codeunit "Config. Validate Management";
        CultureInfo: Codeunit DotNet_CultureInfo;
        TypeHelper: Codeunit "Type Helper";
        TempRecRef: RecordRef;
        FldRef: FieldRef;
        Boo: Boolean;
        Dat: Date;
        Dec: Decimal;
        FldNo: Integer;
        Int: Integer;
        JObj: JsonObject;
        JTok: JsonToken;
        JTok2: JsonToken;
        JKey: Text;
        JVal: Text;
        "Value": Variant;
    begin
        TempRecRef.Open(GetTableNo(), true);

        foreach JTok in Chunk do begin
            JObj := JTok.AsObject();
            TempRecRef.Init();
            foreach JKey in JObj.Keys() do begin
                JObj.Get(JKey, JTok2);
                if not JTok2.AsValue().IsNull() then
                    if Evaluate(FldNo, JKey) then begin
                        FldRef := TempRecRef.field(FldNo);
                        case FldRef."Type" of
                            "Fieldtype"::"Integer":
                                begin
                                    Int := JTok2.AsValue().AsInteger();
                                    JVal := Format(Int);
                                end;
                            "FieldType"::"Decimal":
                                begin
                                    Dec := JTok2.AsValue().AsDecimal();
                                    JVal := Format(Round(Dec, 0.01, '='));
                                end;
                            "FieldType"::"Boolean":
                                begin
                                    Boo := JTok2.AsValue().AsBoolean();
                                    JVal := Format(Boo);
                                end;
                            "FieldType"::"Date":
                                begin
                                    "Value" := Dat;
                                    TypeHelper.Evaluate("Value", Format(JTok2.AsValue().AsText(), 0, 9), '', CultureInfo.CurrentCultureName());
                                    JVal := Format("Value");
                                end;
                            else
                                JVal := JTok2.AsValue().AsText();
                        end;
                        ConfigValidateMgt.EvaluateTextToFieldRef(JVal, FldRef, false);
                    end;
            end;

            TempRecRef.SetTable(TempPostCode);
            TempPostCode.Insert();
        end;

        ImportFromTemp(TempPostCode);
    end;

    local procedure ImportFromTemp(var TempPostCode: Record "Post Code" temporary)
    var
        PostCode: Record "Post Code";
    begin
        if TempPostCode.IsEmpty() then
            exit;

        TempPostCode.FindSet();
        repeat
            if not PostCode.Get(TempPostCode.Code, TempPostCode.City) then begin
                PostCode.TransferFields(TempPostCode, true);
                PostCode.Insert();
                RecsCreated += 1
            end else begin
                PostCode.TransferFields(TempPostCode, false);
                PostCode.Modify();
                RecsUpdates += 1;
            end;
        until TempPostCode.Next() = 0;
    end;

    procedure OnImportFinished(Rec: Record "BYD DI Template")
    var
        PostCode: Record "Post Code";
    begin
        Message(ImportFinishedMsg, RecsCreated, RecsUpdates, PostCode.TableCaption());
        Clear(RecsCreated);
        Clear(RecsUpdates);
    end;

    local procedure CreateField(var Rec: Record "BYD DI Template Field"; FieldNo: Integer; Validate: Boolean; Required: Boolean)
    begin
        Rec.Init();
        Rec."Field No." := FieldNo;
        Rec."Validate Relations" := Validate;
        Rec.Required := Required;
        Rec.Insert();
    end;

    var
        RecsCreated: Integer;
        RecsUpdates: Integer;
        ImportFinishedMsg: Label 'Import done!\%3 created: %1\%3 updated: %2', Comment = '%1 = created, %2 = updated, %3 = table caption';
}