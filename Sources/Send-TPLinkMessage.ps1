Function Send-TPLinkCommand {

    <#

    #>

    [CmdletBinding()]
    param (

        [Parameter(ParameterSetName='FriendlyCommand',Mandatory=$True,Position=0)]
        [ValidateSet(
            'TurnOn',
            'TurnOff',    
            'SystemInfo',
            'Reboot',
            'Reset'
        )]
        [string]$Command,

        [Parameter(ParameterSetName='JSONFormattedCommand',Mandatory=$True,Position=0)]
        [string]$JSON,

        [Parameter(ParameterSetName='FriendlyCommand',Mandatory=$True,Position=1)]
        [Parameter(ParameterSetName='JSONFormattedCommand',Mandatory=$True,Position=1)]
        [ipaddress]$IPAddress,
        
        [Parameter(ParameterSetName='FriendlyCommand',Position=2)]
        [Parameter(ParameterSetName='JSONFormattedCommand',Position=2)]
        [int]$Port = 9999
    
    )

    #Create an instance of the .Net TCP Client class
    $TCPClient = New-Object -TypeName System.Net.Sockets.TCPClient

    #Use the TCP client class to connect to the TP-Link plug
    $TCPClient.connect($IPAddress,$Port)

    #Return the network stream from the TCP client
    $Stream = $TCPClient.GetStream()

    Switch ($PSCmdlet.ParameterSetName) {

        'FriendlyCommand' {

            #Convert the friendly command to the corresponding JSON command
            $JSON = ConvertTo-TPLinkJSONCommand -InputObject $Command

            #Convert the JSON command to TPLink byte format
            $EncodedCommand = ConvertTo-TPLinkDataFormat -Body $JSON

        }

        'JSONFormattedCommand' {

            #Convert the JSON command to TPLink byte format
            $EncodedCommand = ConvertTo-TPLinkDataFormat -Body $JSON

        }

    }

    #Write the command to the TCP Client stream twice. Unsure why twice.
    $Stream.write($EncodedCommand,0,$EncodedCommand.Length)
    $Stream.write($EncodedCommand,0,$EncodedCommand.Length)

    #Wait for data to become available
    While ($TCPClient.Available -eq 0) {
            
        Write-Debug "TCP Client Availablity buffer was not initially filled!"
        Write-Verbose "TCP Client Availablity buffer was not initially filled!"
        Start-Sleep -Seconds 1
    
    }

    #Start an additional half second sleep to allow all of the data to come in
    Start-Sleep -Milliseconds 500

    #Create a Byte object the size of the reponse that will hold the response from the plug.
    $BindResponseBuffer = New-Object Byte[] -ArgumentList $TCPClient.Available    

    #Use the read method and specify the buffer, the offset, and the size
    $Read = $stream.Read($bindResponseBuffer, 0, $bindResponseBuffer.Length)

    #If the read comes back empty, break out of the While loop
    If ($Read -eq 0){
        
        break
    
    } Else {

        [Array]$BytesReceived += $bindResponseBuffer[0..($Read -1)]
        [Array]::Clear($bindResponseBuffer, 0, $Read)
        
    }

    #Debug
    Write-Debug "TCPClient connection status is: $($TCPClient.Connected)"

    If ($BytesReceived -eq $Null) {

        Write-Output "No response received from the plug"

    } Else {

        $Response = ConvertFrom-JSON -InputObject (ConvertFrom-TPLinkDataFormat -Body $BytesReceived)

        Write-Output $Response

    }

    #Cleanup the Network Stack
    $Bytesreceived = $null
    $Response = $null
    $bindResponseBuffer = $null
    $Stream.Flush()
    $Stream.Dispose()
    $Stream.Close()
    $Tcpclient.Dispose()
    $Tcpclient.Close()

}