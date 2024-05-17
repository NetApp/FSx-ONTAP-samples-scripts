################################################################################
# THIS SOFTWARE IS PROVIDED BY NETAPP "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL NETAPP BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR'
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
################################################################################
#
# This script is used to list all the FSxN File Systems a user has access to.
# It accepts two optional parameters:
#  -region <region>
#  -all
#  Where:
#    <region> is the region you want to list the file systems from. By default it
#             list all the file systems from the default region set by the
#             "aws configuration" command.
#    -all means you want to list the file systems from all the known AWS regions.
#    -network means you want the network informaiton associated with the filesystem.
#
##################################################################################

param ([switch]$all, [string]$region, [switch]$network)

if($region -eq "") {
  $region=(get-content ~/.aws/config | select-string "region") -replace "region = ",""
}

if ($all.IsPresent) {
  $regions=(aws ec2 describe-regions --query "Regions[].RegionName" --output=json | ConvertFrom-Json)
} else {
  $regions=@($region)
}

foreach ($region in $regions) {
  $first=$true
  $fss=(aws fsx describe-file-systems --region=$region --output=json | ConvertFrom-Json)

  foreach ($fs in $fss.FileSystems) {
    if($first) {
      #%12s %23s %35s %10s %15s %21s %24s
      if ($network.IsPresent) {
        "`n{0,12} {1,23} {2,35} {3,10} {4, 15} {5, 21} {6, 24}" -f "Region", "File System ID", "Name", "Status", "Management IP", "VPC ID", "Subnet ID"
      } else {
        "`n{0,12} {1,23} {2,35} {3,10} {4, 15}" -f "Region", "File System ID", "Name", "Status", "Management IP"
      }
      $first=$false
    }

    $name="N/A"
    foreach ($tag in $fs.tags) {
      if($tag.Key -eq "Name") {
        $name=$tag.Value
      }
    }
    if ($null -ne $fs.OntapConfiguration.Endpoints.Management.IpAddresses) {
      $manIP = $fs.OntapConfiguration.Endpoints.Management.IpAddresses[0]
    } else {
      $manIP = "N/A"
    }
    if ($network.IsPresent) {
      "{0,12} {1,23} {2,35} {3,10} {4, 15} {5, 21} {6, 24}" -f $region, $fs.FileSystemId, $name, $fs.Lifecycle, $manIP, $fs.VpcId, $fs.SubnetIds[0]
    } else {
      "{0,12} {1,23} {2,35} {3,10} {4, 15}" -f $region, $fs.FileSystemId, $name, $fs.Lifecycle, $manIP
    }
  }
}
