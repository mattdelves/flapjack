require 'spec_helper'
require 'flapjack/gateways/jsonapi/check_presenter'

describe 'Flapjack::Gateways::JSONAPI::CheckPresenter' do

  let(:entity_check) { double(Flapjack::Data::EntityCheck) }

  let(:time) { Time.now.to_i }

  let(:states) {
    [{:state => 'critical', :timestamp => time - (4 * 60 * 60)},
     {:state => 'ok',       :timestamp => time - (4 * 60 * 60) + (5 * 60)},
     {:state => 'critical', :timestamp => time - (3 * 60 * 60)},
     {:state => 'ok',       :timestamp => time - (3 * 60 * 60) + (10 * 60)},
     {:state => 'critical', :timestamp => time - (2 * 60 * 60)},
     {:state => 'ok',       :timestamp => time - (2 * 60 * 60) + (15 * 60)},
     {:state => 'critical', :timestamp => time - (1 * 60 * 60)},
     {:state => 'ok',       :timestamp => time - (1 * 60 * 60) + (20 * 60)}
    ]
  }

  # one overlap at start, one overlap at end, one wholly overlapping,
  # one wholly contained
  let(:maintenances) {
    [{:start_time => time - ((4 * 60 * 60) + (1 * 60)), # 1 minute before outage starts
      :end_time   => time - (4 * 60 * 60) + (2 * 60),   # 2 minutes after outage starts
      :duration => (3 * 60)},
     {:start_time => time - (3 * 60 * 60) + (8 * 60),   # 2 minutes before outage ends
      :end_time   => time - (3 * 60 * 60) + (11 * 60),  # 1 minute after outage ends
      :duration => (3 * 60)},
     {:start_time => time - ((2 * 60 * 60) + (1 * 60)), # 1 minute before outage starts
      :end_time   => time - (2 * 60 * 60) + (17 * 60),  # 2 minutes after outage ends
      :duration => (3 * 60)},
     {:start_time => time - (1 * 60 * 60) + (1 * 60),   # 1 minute after outage starts
      :end_time   => time - (1 * 60 * 60) + (10 * 60),  # 10 minutes before outage ends
      :duration => (9 * 60)}
    ]
  }

  it "returns a list of outage hashes for an entity check" do
    expect(entity_check).to receive(:historical_states).
      with(time - (5 * 60 * 60), time - (2 * 60 * 60)).and_return(states)

    expect(entity_check).to receive(:historical_state_before).
      with(time - (4 * 60 * 60)).and_return(nil)

    ecp = Flapjack::Gateways::JSONAPI::CheckPresenter.new(entity_check)
    outages = ecp.outage(time - (5 * 60 * 60), time - (2 * 60 * 60))
    expect(outages).not_to be_nil
    expect(outages).to be_an(Array)
    expect(outages.size).to eq(4)

    # TODO check the data in those hashes
  end

  it "returns a list of outage hashes with no start and end time set" do
    expect(entity_check).to receive(:historical_states).
      with(nil, nil).and_return(states)

    expect(entity_check).to receive(:historical_state_before).
      with(time - (4 * 60 * 60)).and_return(nil)

    ecp = Flapjack::Gateways::JSONAPI::CheckPresenter.new(entity_check)
    outages = ecp.outage(nil, nil)
    expect(outages).not_to be_nil
    expect(outages).to be_an(Array)
    expect(outages.size).to eq(4)

    # TODO check the data in those hashes
  end

  it "returns a consolidated list of outage hashes with repeated state events" do
    states[1][:state] = 'critical'
    states[2][:state] = 'ok'

    expect(entity_check).to receive(:historical_states).
      with(nil, nil).and_return(states)

    expect(entity_check).to receive(:historical_state_before).
      with(time - (4 * 60 * 60)).and_return(nil)

    ecp = Flapjack::Gateways::JSONAPI::CheckPresenter.new(entity_check)
    outages = ecp.outage(nil, nil)
    expect(outages).not_to be_nil
    expect(outages).to be_an(Array)
    expect(outages.size).to eq(3)
  end

  it "returns a (small) outage hash for a single state change" do
    expect(entity_check).to receive(:historical_states).
      with(nil, nil).and_return([{:state => 'critical', :timestamp => time - (4 * 60 * 60)}])
    expect(entity_check).to receive(:historical_state_before).
      with(time - (4 * 60 * 60)).and_return(nil)

    ecp = Flapjack::Gateways::JSONAPI::CheckPresenter.new(entity_check)
    outages = ecp.outage(nil, nil)
    expect(outages).not_to be_nil
    expect(outages).to be_an(Array)
    expect(outages.size).to eq(1)
  end

  it "a list of unscheduled maintenances for an entity check" do
    expect(entity_check).to receive(:maintenances).
      with(time - (12 * 60 * 60), time, :scheduled => false).and_return(maintenances)

    expect(entity_check).to receive(:maintenances).
      with(nil, time - (12 * 60 * 60), :scheduled => false).and_return([])

    ecp = Flapjack::Gateways::JSONAPI::CheckPresenter.new(entity_check)
    unsched_maint = ecp.unscheduled_maintenance(time - (12 * 60 * 60), time)

    expect(unsched_maint).to be_an(Array)
    expect(unsched_maint.size).to eq(4)

    # TODO check the data in those hashes
  end

  it "a list of scheduled maintenances for an entity check" do
    expect(entity_check).to receive(:maintenances).
      with(time - (12 * 60 * 60), time, :scheduled => true).and_return(maintenances)

    expect(entity_check).to receive(:maintenances).
      with(nil, time - (12 * 60 * 60), :scheduled => true).and_return([])

    ecp = Flapjack::Gateways::JSONAPI::CheckPresenter.new(entity_check)
    sched_maint = ecp.scheduled_maintenance(time - (12 * 60 * 60), time)

    expect(sched_maint).to be_an(Array)
    expect(sched_maint.size).to eq(4)

    # TODO check the data in those hashes
  end

  it "returns downtime and percentage for a downtime check" do
    expect(entity_check).to receive(:historical_states).
      with(time - (12 * 60 * 60), time).and_return(states)

    expect(entity_check).to receive(:historical_state_before).
      with(time - (4 * 60 * 60)).and_return(nil)

    expect(entity_check).to receive(:maintenances).
      with(time - (12 * 60 * 60), time, :scheduled => true).and_return(maintenances)

    expect(entity_check).to receive(:maintenances).
      with(nil, time - (12 * 60 * 60), :scheduled => true).and_return([])

    ecp = Flapjack::Gateways::JSONAPI::CheckPresenter.new(entity_check)
    downtimes = ecp.downtime(time - (12 * 60 * 60), time)

    # 22 minutes, 3 + 8 + 11
    expect(downtimes).to be_a(Hash)
    expect(downtimes[:total_seconds]).to eq({'critical' => (22 * 60),
      'ok' => ((12 * 60 * 60) - (22 * 60))})
    expect(downtimes[:percentages]).to eq({'critical' => (((22 * 60) * 100.0) / (12 * 60 * 60)),
      'ok' => ((((12 * 60 * 60) - (22 * 60)) * 100.0) / (12 * 60 *60))})
    expect(downtimes[:downtime]).to be_an(Array)
    # the last outage gets split by the intervening maintenance period,
    # but the fully covered one gets removed.
    expect(downtimes[:downtime].size).to eq(4)
  end

  it "returns downtime (but no percentage) for an unbounded downtime check" do
    expect(entity_check).to receive(:historical_states).
      with(nil, nil).and_return(states)

    expect(entity_check).to receive(:historical_state_before).
      with(time - (4 * 60 * 60)).and_return(nil)

    expect(entity_check).to receive(:maintenances).
      with(nil, nil, :scheduled => true).and_return(maintenances)

    ecp = Flapjack::Gateways::JSONAPI::CheckPresenter.new(entity_check)
    downtimes = ecp.downtime(nil, nil)

    # 22 minutes, 3 + 8 + 11
    expect(downtimes).to be_a(Hash)
    expect(downtimes[:total_seconds]).to eq({'critical' => (22 * 60)})
    expect(downtimes[:percentages]).to eq({'critical' => nil})
    expect(downtimes[:downtime]).to be_an(Array)
    # the last outage gets split by the intervening maintenance period,
    # but the fully covered one gets removed.
    expect(downtimes[:downtime].size).to eq(4)
  end

  it "returns downtime and handles an unfinished problem state" do
    current = [{:state => 'critical', :timestamp => time - (4 * 60 * 60)},
               {:state => 'ok',       :timestamp => time - (4 * 60 * 60) + (5 * 60)},
               {:state => 'critical', :timestamp => time - (3 * 60 * 60)}]

    expect(entity_check).to receive(:historical_states).
      with(nil, nil).and_return(current)

    expect(entity_check).to receive(:historical_state_before).
      with(time - (4 * 60 * 60)).and_return(nil)

    expect(entity_check).to receive(:maintenances).
      with(nil, nil, :scheduled => true).and_return([])

    ecp = Flapjack::Gateways::JSONAPI::CheckPresenter.new(entity_check)
    downtimes = ecp.downtime(nil, nil)

    expect(downtimes).to be_a(Hash)
    expect(downtimes[:total_seconds]).to eq({'critical' => (5 * 60)})
    expect(downtimes[:percentages]).to eq({'critical' => nil})
    expect(downtimes[:downtime]).to be_an(Array)
    # the last outage gets split by the intervening maintenance period,
    # but the fully covered one gets removed.
    expect(downtimes[:downtime].size).to eq(2)
  end

end
