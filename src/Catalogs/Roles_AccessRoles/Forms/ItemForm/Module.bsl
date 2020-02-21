&AtServer
Var RightsMap, PictureLibData Export;
 
&AtClient
Var ArrayForViewEdit Export;

&AtClient
Procedure RightsObjectTypeOnChange(Item)
	CurrentRow = Items.Rights.CurrentData;
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	CurrentRow.ObjectName = "";
	CurrentRow.ObjectPath = "";
EndProcedure

&AtClient
Procedure RightsObjectNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.Rights.CurrentData;
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	UpdateObjectNameChoiceList(CurrentRow);
EndProcedure


&AtClient
Procedure UpdateObjectNameChoiceList(Val CurrentRow)
	Items.RightsObjectName.ChoiceList.Clear();
	
	If ValueIsFilled(CurrentRow.ObjectType) Then
		For Each Row In Roles_Settings.MetadataInfo().Get(CurrentRow.ObjectType) Do
			Items.RightsObjectName.ChoiceList.Add(Row.Value);
		EndDo;
	EndIf;
EndProcedure

&AtClient
Procedure RightsObjectNameOnChange(Item)
	CurrentRow = Items.Rights.CurrentData;
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	Data = StrSplit(CurrentRow.ObjectName, ".", False);
	If Data.Count() > 1 Then
		CurrentRow.ObjectType = PredefinedValue("Enums.Roles_MetadataTypes." + Data[0]);
		UpdateObjectNameChoiceList(CurrentRow);
		CurrentRow.ObjectName = Data[1];
	EndIf;
	CurrentRow.ObjectPath = Roles_Settings.MetaName(CurrentRow.ObjectType) + "." + CurrentRow.ObjectName;
EndProcedure

&AtClient
Procedure RightsRightNameStartChoice(Item, ChoiceData, StandardProcessing)
	CurrentRow = Items.Rights.CurrentData;
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	UpdateRightChoiceList(CurrentRow);
EndProcedure

&AtClient
Procedure UpdateRightChoiceList(Val CurrentRow)
	Items.RightsRightName.ChoiceList.LoadValues(Roles_Settings.RolesSet().Get(CurrentRow.ObjectType));
EndProcedure

&AtClient
Procedure RightsBeforeDeleteRow(Item, Cancel)
	CurrentRow = Item.CurrentData;
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	RowsToDelete = Object.RestrictionByCondition.FindRows(New Structure("RowID", CurrentRow.RowID));
	For Each RowToDelete In RowsToDelete Do
		Object.RestrictionByCondition.Delete(RowToDelete);
	EndDo;
EndProcedure

&AtClient
Procedure RightsOnChange(Item)
	CurrentRow = Item.CurrentData;
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	If NOT ValueIsFilled(CurrentRow.RowID) Then
		CurrentRow.RowID = New UUID();
	EndIf;
	MatrixUpdated = False;
EndProcedure

&AtClient
Procedure RestrictionByConditionOnChange(Item)
	CurrentRightRow = Items.Rights.CurrentData;
	If CurrentRightRow = Undefined Then
		Return;
	EndIf;
	
	CurrentRow = Item.CurrentData;
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	CurrentRow.RowID = CurrentRightRow.RowID;
EndProcedure

&AtClient
Procedure UpdateRights(Command)
	RolesEdit.GetItems().Clear();
	Message("I" + CurrentDate());
	UpdateRightsList(NOT MatrixUpdated);
	Message("V" + CurrentDate());
EndProcedure

#Region RightsList
&AtServer
Procedure UpdateRightsList(OnlyReport)
	RoleTree = FormAttributeToValue("RolesEdit");
	ObjectData = New Structure;
	ObjectData.Insert("RightTable", Object.Rights.Unload());
	ObjectData.Insert("RestrictionByCondition", Object.RestrictionByCondition.Unload());
	ObjectData.Insert("SetRightsForNewNativeObjects", Object.SetRightsForNewNativeObjects);
	ObjectData.Insert("SetRightsForAttributesAndTabularSectionsByDefault", Object.SetRightsForAttributesAndTabularSectionsByDefault);
	ObjectData.Insert("SubordinateObjectsHaveIndependentRights", Object.SubordinateObjectsHaveIndependentRights);
	Message("II" + CurrentDate());
	TabDocMartix = Roles_RoleMatrix.GenerateRoleMatrix(RoleTree, ObjectData, OnlyReport);
	Message("III" + CurrentDate());
	ValueToFormAttribute(RoleTree, "RolesEdit");
	Message("IV" + CurrentDate());
EndProcedure

&AtClient
Procedure RolesEditBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;
EndProcedure

&AtClient
Procedure RolesEditBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

#Region Service

#Region FlagStatus
&AtClient
Procedure FlagOnChange(Item)
    RowID = Items.RolesEdit.CurrentRow;
	
	If RowID = Undefined Then
		Return;
	EndIf;
	
	ItemRow = RolesEdit.FindByID(RowID);
	
	If ItemRow[Item.Name] = 2 Then
		ItemRow[Item.Name] = 0;
	EndIf;
	
	If ItemRow.ObjectType = PredefinedValue("Enum.Roles_MetadataTypes.Subsystem") Then
		SetFlag(ItemRow, Item, ArrayForViewEdit);
	Else
		Parent = ItemRow.GetParent();
		While Parent <> Undefined Do
			
			If NOT Parent.ObjectSubtype = ItemRow.ObjectSubtype Then
				Break;
			EndIf;
			
			If Skip(Item, Parent) Then
				Break;
			EndIf;
			Parent[Item.Name] = ?(isAllSet(ArrayForViewEdit, Item, ItemRow),
						ItemRow[Item.Name], 3);
			ItemRow = Parent;
			Parent = ItemRow.GetParent();
		EndDo;
	EndIf;
	
	
EndProcedure

&AtClient
Procedure SetFlag(ItemRow, Item, ArrayForViewEdit)
    Childs = ItemRow.GetItems();
	For Each ThisItem In Childs Do
		
		If NOT ThisItem.ObjectSubtype = ItemRow.ObjectSubtype Then
			Break;
		EndIf;
		
		If Skip(Item, ThisItem) Then
			Continue;
		EndIf;
        ThisItem[Item.Name] = ItemRow[Item.Name];
        SetFlag(ThisItem, Item, ArrayForViewEdit);
    EndDo;
EndProcedure

&AtClient
Function Skip(Val Item, Val ThisItem)
	
	If NOT ThisItem.ObjectSubtype.isEmpty() Then
		If Item.Name = "View" Then
			If ThisItem.ObjectSubtype = PredefinedValue("Enum.Roles_MetadataSubtype.Command")
				OR NOT ArrayForViewEdit.Find(ThisItem.ObjectSubtype) = Undefined Then
				Return False;
			Else
				Return True;
			EndIf;
		ElsIf (Item.Name = "Read" OR Item.Name = "Update")
			AND ThisItem.ObjectSubtype = PredefinedValue("Enum.Roles_MetadataSubtype.Recalculation") Then
			Return False;
		ElsIf Item.Name = "Edit" 
			AND NOT ArrayForViewEdit.Find(ThisItem.ObjectSubtype) = Undefined Then
			Return False;
		Else	
			Return True;
		EndIf;
	Else
		If Item.Name = "Edit" Then 
			If ThisItem.ObjectType = PredefinedValue("Enum.Roles_MetadataTypes.DataProcessor")
				OR ThisItem.ObjectType = PredefinedValue("Enum.Roles_MetadataTypes.Report")
				OR ThisItem.ObjectType = PredefinedValue("Enum.Roles_MetadataTypes.DocumentJournal") Then
				Return True;
			Else 
				Return False;
			EndIf;
		Else	
			Return False;
		EndIf;
	EndIf;
	Return False;
EndFunction

&AtClient
Function isAllSet(Val ArrayForViewEdit, Val Item, Val ItemRow)
    UpChilds = ItemRow.GetParent().GetItems();
	For Each thisItem In UpChilds Do
		
		If Skip(Item, thisItem) Then
			Continue;
		EndIf;
		
        If NOT thisItem[Item.Name] = ItemRow[Item.Name] Then
            Return False;
        EndIf;
    EndDo;
    Return True;
КонецФункции   
#EndRegion

&AtServer
Procedure SetOnChangeAction()
	
	ArrayChildItems = New Array;
	ArrayChildItems.Add(Items.RolesEditGroupAdmin.ChildItems);
	ArrayChildItems.Add(Items.RolesEditGroupBasic.ChildItems);
	ArrayChildItems.Add(Items.RolesEditGroupDocument.ChildItems);
	ArrayChildItems.Add(Items.RolesEditGroupHistory.ChildItems);
	ArrayChildItems.Add(Items.RolesEditGroupInteractive.ChildItems);
	ArrayChildItems.Add(Items.RolesEditGroupPredefined.ChildItems);
	ArrayChildItems.Add(Items.RolesEditGroupRLS.ChildItems);
	ArrayChildItems.Add(Items.RolesEditGroupSessionParameters.ChildItems);
	ArrayChildItems.Add(Items.RolesEditGroupTask.ChildItems);
	For Each ChildItem In ArrayChildItems Do
		For Each Item In ChildItem Do
			Item.SetAction("OnChange", "ChangeRole"); 
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetOnChangeAction();
	If Object.Ref.IsEmpty() Then
		Object.SetRightsForAttributesAndTabularSectionsByDefault = True;
	EndIf;

	UpdateRightsList(True);
EndProcedure

&AtClient
Procedure SearchTextOnChange(Item)
	If ValueIsFilled(SearchText) Then
		Items.RolesEdit.Representation = TableRepresentation.List;
	Else
		Items.RolesEdit.Representation = TableRepresentation.Tree;
	EndIf;
EndProcedure

&AtClient
Procedure RolesEditSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	CurrentRow = Items.RolesEdit.CurrentData;
	SetFlags(CurrentRow, Field);
EndProcedure

&AtClient
Procedure SetFlags(CurrentRow,  Field, Value = Undefined)
	
	If Skip(Field, CurrentRow) Then
		Return;
	EndIf;
	
	If NOT Value = Undefined Then
		CurrentRow[Field.Name] = Value;
	ElsIf CurrentRow[Field.Name] = 0 Then
		CurrentRow[Field.Name] = 1;
	ElsIf CurrentRow[Field.Name] = 1 Then
		CurrentRow[Field.Name] = 2;
	Else
		CurrentRow[Field.Name] = 0;
	EndIf;
	CurrentRow.Edited = True;
	SetEditedInfo(CurrentRow);
	
	Info = StrSplit(CurrentRow.ObjectPath, ".");
	
	If Info.Count() = 1 Then
		For Each RowChild In CurrentRow.GetItems() Do
			SetFlags(RowChild,  Field, CurrentRow[Field.Name]);
		EndDo;
		Return;
	EndIf;
	
	Filter = New Structure();
	Filter.Insert("RightName", PredefinedValue("Enum.Roles_Rights." + Field.Name));
	Filter.Insert("ObjectPath", CurrentRow.ObjectPath);
	Row = Object.Rights.FindRows(Filter);
	
	If Row.Count() Then
		If CurrentRow[Field.Name] = 0 Then
			Row[0].Disable = True;
		Else
			Row[0].RightValue = ?(CurrentRow[Field.Name] = 1, True, False);
			Row[0].Disable = False;
		EndIf;
	Else
		NewRow = Object.Rights.Add();
		NewRow.ObjectType = PredefinedValue("Enum.Roles_MetadataTypes." + Info[0]);
		NewRow.ObjectName = Info[1];
		NewRow.RightName = PredefinedValue("Enum.Roles_Rights." + Field.Name);
		NewRow.ObjectPath = CurrentRow.ObjectPath;
		NewRow.RightValue = ?(CurrentRow[Field.Name] = 1, True, False);
		NewRow.RowID = New UUID;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetEditedInfo(Row)
	Parent = Row.GetParent();
	If Parent = Undefined Then
		Return;
	EndIf;
	If Parent.Edited Then
		Return;
	EndIf;
	Parent.Edited = True;
	SetEditedInfo(Parent);
EndProcedure

&AtClient
Procedure RolesEditOnActivateCell(Item)

	If NOT (Item.CurrentItem.Name = "Read"
		OR Item.CurrentItem.Name = "Insert"
		OR Item.CurrentItem.Name = "Update"
		OR Item.CurrentItem.Name = "Delete") Then
			Return;
	EndIf;
	RightName = PredefinedValue("Enum.Roles_Rights." + Item.CurrentItem.Name);
	
	
EndProcedure

&AtClient
Procedure GroupMainPagesOnCurrentPageChange(Item, CurrentPage)
	If CurrentPage = Items.GroupRoleMatrix 
		AND NOT MatrixUpdated Then
		
		RolesEdit.GetItems().Clear();
		Message("I" + CurrentDate());
		UpdateRightsList(False);
		MatrixUpdated = True;
		Message("V" + CurrentDate());
	EndIf;
EndProcedure

ArrayForViewEdit = Roles_SettingsReUse.ArrayForViewEdit();