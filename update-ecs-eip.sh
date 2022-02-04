#!/bin/bash

PROFILE='hongk'
REGIONID='cn-hongkong'
VMID='i-j6c1c4died0avdi3969m'
DOMAIN='binarii.cc'
RR='hongk'

get_eip_id_of_instance() {
    echo >&2 "Getting EIP id of instance:  RegionId=\"$1\", InstanceId=\"$2\""
    echo $(aliyun --profile "$PROFILE" ecs DescribeInstances --RegionId="$1" --InstanceIds=[\"$2\"] |jq -r '.Instances.Instance[0].EipAddress.AllocationId')
}

allocate_eip_address() {
    echo >&2 "Allocating new EIP: RegionId=\"$1\""
    echo $(aliyun --profile "$PROFILE" ecs AllocateEipAddress --RegionId="$1" --Bandwidth=200 --InternetChargeType='PayByTraffic')
}

bind_eip_address() {
    echo >&2 "Binding EIP to instance: InstanceId=\"$2\", EipId=\"$1\""
    aliyun --profile "$PROFILE" ecs AssociateEipAddress  --AllocationId="$1" --InstanceId="$2" > /dev/null
    aliyun --profile "$PROFILE" ecs DescribeEipAddresses --AllocationId="$1" --waiter expr='EipAddresses.EipAddress[0].Status' to='InUse' > /dev/null
}

unbind_eip_address() {
    echo >&2 "Unbinding EIP from instance: InstanceId=\"$2\", EipId=\"$1\""
    aliyun --profile "$PROFILE" ecs UnassociateEipAddress --AllocationId="$1" --InstanceId="$2" > /dev/null
    aliyun --profile "$PROFILE" ecs DescribeEipAddresses  --AllocationId="$1" --waiter expr='EipAddresses.EipAddress[0].Status' to='Available' > /dev/null
}

release_eip_address() {
    echo >&2 "Releasing EIP: RegionId=\"$1\", EipId=\"$2\""
    aliyun --profile "$PROFILE" ecs ReleaseEipAddress --RegionId="$1" --AllocationId="$2" > /dev/null
}

get_record_id_of_domain() {
    echo >&2 "Getting DNS record id of domain: DomainName=\"$1\", RRKeyWord=\"$2\""
    echo $(aliyun --profile "$PROFILE" alidns DescribeDomainRecords --DomainName="$1" --RRKeyWord="$2" --Type='A' |jq -r '.DomainRecords.Record[0].RecordId')
}

update_domain_record() {
    echo >&2 "Updating DNS record: RecordId=\"$1\", RR=\"$2\", Value=\"$3\""
    aliyun --profile "$PROFILE" alidns UpdateDomainRecord       --RecordId="$1" --Type='A' --RR="$2" --Value="$3" > /dev/null
    aliyun --profile "$PROFILE" alidns DescribeDomainRecordInfo --RecordId="$1" --waiter expr='Value' to="$3" > /dev/null
}

echo "Using profile: $PROFILE"

OLD_EIP_ID=$(get_eip_id_of_instance "$REGIONID" "$VMID")
unbind_eip_address "$OLD_EIP_ID" "$VMID"
release_eip_address "$REGIONID" "$OLD_EIP_ID"

NEW_EIP=$(allocate_eip_address "$REGIONID")
NEW_EIP_ID=$(echo "$NEW_EIP" |jq -r '.AllocationId')
NEW_EIP_ADDRESS=$(echo "$NEW_EIP" |jq -r '.EipAddress')
bind_eip_address "$NEW_EIP_ID" "$VMID"

DOMAIN_RECORD_ID=$(get_record_id_of_domain "$DOMAIN" "$RR")
update_domain_record "$DOMAIN_RECORD_ID" "$RR" "$NEW_EIP_ADDRESS"

echo "Done"

exit 0
