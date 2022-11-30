classdef PlaceFieldMapMeasures < neuro.placeField.PlaceFieldMap
    %PLACEFIELDMAPMAESURES Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Information
        Stability
        PlaceFields
    end
    
    methods
        function obj = PlaceFieldMapMeasures(placeFieldMap)
            %PLACEFIELDMAPMAESURES Construct an instance of this class
            %   Detailed explanation goes here
            fnames=fieldnames(placeFieldMap);
            for ifn=1:numel(fnames)
                obj.(fnames{ifn})=placeFieldMap.(fnames{ifn});
            end
            obj.Information=obj.calculateInformation;
            if min(size(obj.MapSmooth))==1
                [obj.Stability.gini,...
                    obj.Stability.cum,...
                    obj.Stability.basecum]=...
                    obj.calculateStabilityGini;
                obj.PlaceFields=obj.calculatePlaceFields;
            end
        end
        
        function information = calculateInformation(obj)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            mapFR=obj.MapSmooth;
            idx=obj.OccupancyMap>eps;
            posbinsFR=mapFR(idx);
            Pi=obj.OccupancyMap(idx)/sum(obj.OccupancyMap(idx));
            duration=sum(~isnan(obj.PositionData.data.X))/...
                obj.PositionData.time.getSampleRate;
            meanFiringRate=height(obj.SpikePositions)/duration;
            FRiRatio=posbinsFR/meanFiringRate;
            els=Pi.*FRiRatio.*log2(FRiRatio);
            information=sum(els,'omitnan');
        end
        function [gini, cumfiring2, basecumfire]= calculateStabilityGini(obj)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            pfs=obj.calculatePlaceFields;
            pf=pfs(1,:);
            pfrang=round([pf.Position-pf.Width/2 pf.Position+pf.Width/2]);
            pdata= obj.PositionData;
            idx=pdata.data.X>pfrang(1)&pdata.data.X<pfrang(2);
            tp1=pdata.time.getTimePointsInSecZT;
            tp=tp1(idx);
            tps=zeros(size(tp));
            stimes=obj.SpikeUnitTracked.getTimesInSecZT;
            for is=1:numel(stimes)
                [val,loc]=min(abs(stimes(is)-tp));
                if val<1/pdata.time.getSampleRate
                    tps(loc)=tps(loc)+1;
                end
            end
            cumfiring1=cumsum(tps);
            cumfiring2 = cumfiring1/max(cumfiring1);
            b=sum(cumfiring2);
            basecumfire=linspace(0,1,numel(cumfiring2));
            apb=sum(basecumfire);
            gini=1-abs(apb-b)/apb;
        end
        function [corr1]= calculateStabilityCorr(obj,sections)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            time=obj.SpikeUnitTracked.Time;
            st=time.getStartTimeZT;et=time.getEndTimeZT;
            frames=linspace(st,et,sections+1);
            pfms=neuro.placeField.PlaceFieldMapMeasures.empty([sections 0]);
            for isec=1:sections
                frame=frames([isec isec+1]);
                pdsmall=obj.SpikeUnitTracked.PositionData.getWindow( ...
                    neuro.time.ZeitgeberTime( ...
                    frame,time.getZeitgeberTime));
                sutsmall=obj.SpikeUnitTracked+pdsmall;
                frm=sutsmall.getFireRateMap(obj.XEdges,obj.ZEdges);
                pfm=frm.getPlaceFieldMap;
                pfms(isec)=pfm;
                mat(:,isec)=reshape(pfm.MapOriginal,[],1); %#ok<AGROW> 
            end
            [corr1.R,corr1.P]=corr(mat);
            corr1.maps=pfms;
        end
        function peaks = calculatePlaceFields(obj)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            peaks1=obj.getPeakLocalMaxima;
            peaks=sortrows(peaks1,"FiringRate","descend");
        end
    end
end

