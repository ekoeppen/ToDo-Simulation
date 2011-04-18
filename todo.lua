local simulua = require "simulua"
local queue = require "queue"
local rng = require "rng"

-- parameters
local simperiod = 200
local generation_interval = 2
local generation_deviation = 0.3
local handling_duration = 1
local pause_duration = 1
local pause_deviation = 0.2
local handling_deviation = 0.1
local dismissal_chance = 0.1
local skip_chance = 10
local per_page = 10

-- variables
local active = 0
local new = {}
local n = 0
local last_page = 0
local current_page = 0
local r = rng()

-- processes
local worker, taskgen

local function task()
    local self = {}
    
    self.report = function()
        print(string.format("[%04d] Task %d: Status %s, lifetime: %d", simulua.time(),
            self.n, self.status, simulua.time() - self.start_time))
    end
    
    return simulua.process(function()
        self.n = n
        self.status = "new"
        self.start_time = simulua.time()
        self:report()
        n = n + 1
        new[last_page]:into(self)
        if #new[last_page] > per_page then
            last_page = last_page + 1
            new[last_page] = queue()
        end
        worker:start_if_idle()
        simulua.passivate()
        self.status = "done"
        self:report()
    end, self)
end

worker = {}

function worker:report()
    print(string.format("[%04d] Worker: Status %s, current page: %d, task: %d",
        simulua.time(), self.status, current_page, worker.task.n))
end
    
worker.process = simulua.process(function(self)
    while true do
        while not new[current_page]:isempty() do
            worker.task = new[current_page]:retrieve()
            worker.status = "working"
            worker:report()
            simulua.hold(math.abs(r:norm(handling_duration, handling_variation)))
            worker.status = "idle"
            worker:report()
            simulua.hold(math.abs(r:norm(pause_duration, pause_variation)))
            simulua.activate(worker.task)
            if new[current_page]:isempty() or r:unifint(0, 100) > skip_chance then
                current_page = current_page + 1
                if current_page > last_page then current_page = 0 end
            end
        end
        simulua.passivate()
    end
end)

worker.start_if_idle = function()
    if simulua.idle(worker.process) then simulua.activate(worker.process) end
end


taskgen = simulua.process(function()
    while simulua.time() < simperiod do
        simulua.activate(task())
        simulua.hold(math.abs(r:norm(generation_interval, genration_deviation)))
    end
end)

-- simulation
simulua.start(function() -- main
    new[last_page] = queue()
    simulua.activate(taskgen)

    simulua.hold(simperiod)
    print(string.format("Simulation ends %d, pages: %d ", simulua.time(), last_page))
end)

