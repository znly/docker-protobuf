build-image:
	docker build . -t 541497436480.dkr.ecr.eu-west-1.amazonaws.com/protoc

push-image:
	docker push 541497436480.dkr.ecr.eu-west-1.amazonaws.com/protoc:latest
