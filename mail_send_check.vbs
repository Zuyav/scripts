Rem From https://blog.csdn.net/duanjianmin/article/details/6616691
Private Sub Application_ItemSend(ByVal Item As Object, Cancel As Boolean)
    Dim objRecip As Recipient
    Dim objContact As ContactItem
    Dim strExternal As String
    Dim endl As String

    strRecipients = ""
    strCarbonCopys = ""
    endl = vbCr & vbLf

    If Item.MessageClass Like "IPM.TaskRequest*" Then
        Set Item = Item.GetAssociatedTask(False)
    End If

    For Each objRecipient In Item.Recipients
        Set objContact = FindContactByAddress(objRecipient.Address)
        If objRecipient.Type = olCC Then
            If objContact Is Nothing Then
                If LCase(objRecipient.Address) Like "/o=*" Then
                    strCarbonCopys = strCarbonCopys & "    内部 - " & objRecipient.Name & vbCr
                Else
                    strCarbonCopys = strCarbonCopys & "    外部 - " & objRecipient.Name & vbCr
                End If
            End If
        Else
            If objContact Is Nothing Then
                If LCase(objRecipient.Address) Like "/o=*" Then
                    strRecipients = strRecipients & "    内部 - " & objRecipient.Name & vbCr
                Else
                    strRecipients = strRecipients & "    外部 - " & objRecipient.Name & vbCr
                End If
            End If
        End If
    Next
    
    If strRecipients <> "" Then
        MSGText = _
            "主题：" & endl & _
            "    " & Item.Subject & endl & _
            "收件人：" & endl & _
            strRecipients
        If strCarbonCopys <> "" Then
            MSGText = MSGText & "抄送：" & endl & strCarbonCopys
        End If

        If MsgBox(MSGText, vbYesNo, "确认要发送该邮件吗？") = vbNo Then
            Cancel = True
        End If
    End If
End Sub

Private Function FindContactByAddress(strAddress As String)
Dim objContacts
    Dim objContact
    Set objContacts = Application.Session.GetDefaultFolder(olFolderContacts)
    Set objContact = objContacts.Items.Find("[Email1Address] = '" & strAddress _
        & "' or [Email2Address] = '" & strAddress _
        & "' or [Email3Address] = '" & strAddress & "'")
    Set FindContactByAddress = objContact

End Function
                
